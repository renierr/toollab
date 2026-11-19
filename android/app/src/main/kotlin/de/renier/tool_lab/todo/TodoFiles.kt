package de.renier.tool_lab.todo

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

data class TodoAlarmEntry(
    val key: String,
    val taskId: String,
    val at: Long,
    val alarm: Boolean,
    val title: String,
    val body: String,
    val color: Int,
    /** Minutes until it rings again while the task is open; 0 rings once. */
    val repeat: Int = 0,
    val listId: String? = null,
    val digest: Boolean = false,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("key", key)
        .put("taskId", taskId)
        .put("at", at)
        .put("alarm", alarm)
        .put("title", title)
        .put("body", body)
        .put("color", color.toLong() and 0xFFFFFFFFL)
        .apply {
            if (repeat > 0) put("repeat", repeat)
            if (listId != null) put("listId", listId)
            if (digest) put("kind", "digest")
        }

    companion object {
        fun fromJson(json: JSONObject): TodoAlarmEntry? {
            val taskId = json.optString("taskId").takeIf { it.isNotEmpty() } ?: return null
            val at = json.optLong("at", -1L).takeIf { it > 0 } ?: return null
            return TodoAlarmEntry(
                key = json.optString("key").ifEmpty { "$taskId@$at" },
                taskId = taskId,
                at = at,
                alarm = json.optBoolean("alarm", false),
                title = json.optString("title"),
                body = json.optString("body"),
                color = json.optLong("color", 0xFF4FC3F7L).toInt(),
                repeat = json.optInt("repeat", 0).coerceAtLeast(0),
                listId = json.optString("listId").takeIf { it.isNotEmpty() },
                digest = json.optString("kind") == "digest",
            )
        }
    }
}

data class TodoWidgetTask(
    val id: String,
    val title: String,
    val meta: String,
    val overdue: Boolean,
    val important: Boolean,
)

data class TodoWidgetList(
    val id: String,
    val name: String,
    val color: Int,
    val icon: String,
    val openCount: Int,
    val tasks: List<TodoWidgetTask>,
)

object TodoFiles {
    const val ALARMS = "alarms.json"
    const val SNOOZES = "snoozes.json"
    const val ACTIONS = "pending_actions.jsonl"
    const val WIDGET = "widget.json"

    private val lock = Any()

    fun dir(context: Context): File = File(context.filesDir, "todo").apply { mkdirs() }

    fun readJson(context: Context, name: String): JSONObject? = synchronized(lock) {
        val file = File(dir(context), name)
        if (!file.exists()) return null
        try {
            JSONObject(file.readText())
        } catch (e: Exception) {
            android.util.Log.w("TodoFiles", "Unreadable $name: ${e.message}")
            null
        }
    }

    fun writeAtomic(context: Context, name: String, json: JSONObject): Unit = synchronized(lock) {
        val target = File(dir(context), name)
        val tmp = File(dir(context), "$name.tmp")
        tmp.writeText(json.toString())
        if (!tmp.renameTo(target)) {
            target.delete()
            tmp.renameTo(target)
        }
    }

    // Dart drains by renaming the file, so an append never lands in a file being read.
    fun appendAction(context: Context, action: JSONObject): Unit = synchronized(lock) {
        FileOutputStream(File(dir(context), ACTIONS), true).use { out ->
            out.channel.lock().use {
                out.write((action.toString() + "\n").toByteArray())
                out.flush()
            }
        }
    }

    fun readEntries(context: Context, name: String): List<TodoAlarmEntry> {
        val array = readJson(context, name)?.optJSONArray("entries") ?: return emptyList()
        return (0 until array.length()).mapNotNull { i ->
            array.optJSONObject(i)?.let(TodoAlarmEntry::fromJson)
        }
    }

    fun snoozeMinutes(context: Context): Int =
        (readJson(context, ALARMS)?.optInt("snoozeMinutes", 10) ?: 10).coerceAtLeast(1)

    /** Tasks Dart saw done or deleted; their snoozes and repeats are dropped. */
    fun stoppedTasks(context: Context): Set<String> {
        val array = readJson(context, ALARMS)?.optJSONArray("stopped") ?: return emptySet()
        return (0 until array.length()).mapNotNull { array.optString(it).takeIf { id -> id.isNotEmpty() } }.toSet()
    }

    fun removeSnoozes(context: Context, taskId: String): Boolean {
        val snoozes = readEntries(context, SNOOZES)
        if (snoozes.none { it.taskId == taskId }) return false
        writeSnoozes(context, snoozes.filter { it.taskId != taskId })
        return true
    }

    fun writeSnoozes(context: Context, entries: List<TodoAlarmEntry>) = writeEntries(context, SNOOZES, entries)

    fun writeEntries(context: Context, name: String, entries: List<TodoAlarmEntry>) {
        val array = JSONArray()
        entries.sortedBy { it.at }.forEach { array.put(it.toJson()) }
        writeAtomic(
            context,
            name,
            JSONObject()
                .put("version", 1)
                .put("generatedAt", System.currentTimeMillis())
                .put("entries", array),
        )
    }

    fun readWidgetLists(context: Context): List<TodoWidgetList> {
        val array = readJson(context, WIDGET)?.optJSONArray("lists") ?: return emptyList()
        return (0 until array.length()).mapNotNull { i ->
            val list = array.optJSONObject(i) ?: return@mapNotNull null
            val tasksJson = list.optJSONArray("tasks") ?: JSONArray()
            TodoWidgetList(
                id = list.optString("id"),
                name = list.optString("name"),
                color = list.optLong("color", 0xFF4FC3F7L).toInt(),
                icon = list.optString("icon"),
                openCount = list.optInt("openCount", tasksJson.length()),
                tasks = (0 until tasksJson.length()).mapNotNull { j ->
                    val t = tasksJson.optJSONObject(j) ?: return@mapNotNull null
                    TodoWidgetTask(
                        id = t.optString("id"),
                        title = t.optString("title"),
                        meta = t.optString("meta"),
                        overdue = t.optBoolean("overdue", false),
                        important = t.optBoolean("important", false),
                    )
                },
            )
        }
    }

    // Optimistic removal so the widget reflects a completion before Dart drains the queue.
    fun removeTaskFromWidget(context: Context, taskId: String): Unit = synchronized(lock) {
        val root = readJson(context, WIDGET) ?: return
        val lists = root.optJSONArray("lists") ?: return
        var changed = false
        for (i in 0 until lists.length()) {
            val list = lists.optJSONObject(i) ?: continue
            val tasks = list.optJSONArray("tasks") ?: continue
            val kept = JSONArray()
            var removed = false
            for (j in 0 until tasks.length()) {
                val task = tasks.optJSONObject(j) ?: continue
                if (task.optString("id") == taskId) removed = true else kept.put(task)
            }
            if (removed) {
                list.put("tasks", kept)
                list.put("openCount", (list.optInt("openCount", 1) - 1).coerceAtLeast(0))
                changed = true
            }
        }
        if (changed) writeAtomic(context, WIDGET, root)
    }
}
