#ifndef RUNNER_TODO_NOTIFY_HANDLER_H_
#define RUNNER_TODO_NOTIFY_HANDLER_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// Registers "de.renier.tool_lab/todo_desktop"; "notify" shows a tray balloon,
// which Windows 10/11 render as a toast.
void RegisterTodoNotifyHandler(flutter::BinaryMessenger* messenger, HWND owner);

// Removes the tray icon; call before the owner window goes away.
void DisposeTodoNotifyHandler();

#endif  // RUNNER_TODO_NOTIFY_HANDLER_H_
