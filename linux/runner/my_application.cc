#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GdkWindowState window_state;
  gint window_width;
  gint window_height;
  gboolean window_maximized;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static constexpr gint kDefaultWidth = 1280;
static constexpr gint kDefaultHeight = 720;
static constexpr gint kMinExtent = 200;
static constexpr char kWindowGroup[] = "window";

// Sizes a compositor imposes (maximized, fullscreen, tiled e.g. by Hyprland)
// are not the user's floating size and must not overwrite it.
static constexpr GdkWindowState kImposedSizeStates = static_cast<GdkWindowState>(
    GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN |
    GDK_WINDOW_STATE_TILED | GDK_WINDOW_STATE_TOP_TILED |
    GDK_WINDOW_STATE_RIGHT_TILED | GDK_WINDOW_STATE_BOTTOM_TILED |
    GDK_WINDOW_STATE_LEFT_TILED);

static gchar* window_state_path() {
  return g_build_filename(g_get_user_config_dir(), APPLICATION_ID,
                          "window-state.ini", nullptr);
}

static gboolean fits_any_monitor(GdkDisplay* display, gint width, gint height) {
  for (gint i = 0; i < gdk_display_get_n_monitors(display); i++) {
    GdkRectangle area;
    gdk_monitor_get_workarea(gdk_display_get_monitor(display, i), &area);
    if (width <= area.width && height <= area.height) {
      return TRUE;
    }
  }
  return FALSE;
}

// Falls back to the default size when nothing is saved or it no longer fits.
static void load_window_state(MyApplication* self, GtkWindow* window) {
  self->window_width = kDefaultWidth;
  self->window_height = kDefaultHeight;
  self->window_maximized = FALSE;

  g_autoptr(GKeyFile) file = g_key_file_new();
  g_autofree gchar* path = window_state_path();
  if (!g_key_file_load_from_file(file, path, G_KEY_FILE_NONE, nullptr)) {
    return;
  }
  g_autoptr(GError) error = nullptr;
  const gint width = g_key_file_get_integer(file, kWindowGroup, "width", &error);
  if (error) return;
  const gint height =
      g_key_file_get_integer(file, kWindowGroup, "height", &error);
  if (error) return;
  const gboolean maximized =
      g_key_file_get_boolean(file, kWindowGroup, "maximized", &error);
  if (error) return;

  if (width < kMinExtent || height < kMinExtent ||
      !fits_any_monitor(gtk_widget_get_display(GTK_WIDGET(window)), width,
                        height)) {
    return;
  }
  self->window_width = width;
  self->window_height = height;
  self->window_maximized = maximized;
}

static void save_window_state(MyApplication* self) {
  if (self->window_width == 0) {
    return;
  }
  g_autoptr(GKeyFile) file = g_key_file_new();
  g_key_file_set_integer(file, kWindowGroup, "width", self->window_width);
  g_key_file_set_integer(file, kWindowGroup, "height", self->window_height);
  g_key_file_set_boolean(file, kWindowGroup, "maximized",
                         self->window_maximized);

  g_autofree gchar* path = window_state_path();
  g_autofree gchar* dir = g_path_get_dirname(path);
  g_autoptr(GError) error = nullptr;
  if (g_mkdir_with_parents(dir, 0700) != 0 ||
      !g_key_file_save_to_file(file, path, &error)) {
    g_warning("Failed to save window state to %s", path);
  }
}

static gboolean window_state_event_cb(GtkWidget* widget,
                                      GdkEventWindowState* event,
                                      MyApplication* self) {
  self->window_state = event->new_window_state;
  if (!(event->new_window_state & GDK_WINDOW_STATE_FULLSCREEN)) {
    self->window_maximized =
        (event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED) != 0;
  }
  return FALSE;
}

static void size_allocate_cb(GtkWidget* widget,
                             GdkRectangle* allocation,
                             MyApplication* self) {
  if (self->window_state & kImposedSizeStates) {
    return;
  }
  gtk_window_get_size(GTK_WINDOW(widget), &self->window_width,
                      &self->window_height);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Let the window manager (or compositor, e.g. Hyprland) handle window
  // decorations. No client-side title bar or header bar is set so that
  // tiling window managers can control chrome entirely.
  gtk_window_set_title(window, "ToolLab");

  // Wayland gives clients no say over position, and a tiling compositor
  // overrides the size too; there this only matters once a window floats.
  load_window_state(self, window);
  gtk_window_set_default_size(window, self->window_width, self->window_height);
  gtk_window_set_position(window, GTK_WIN_POS_CENTER);
  if (self->window_maximized) {
    gtk_window_maximize(window);
  }
  g_signal_connect(window, "window-state-event",
                   G_CALLBACK(window_state_event_cb), self);
  g_signal_connect(window, "size-allocate", G_CALLBACK(size_allocate_cb),
                   self);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  save_window_state(MY_APPLICATION(application));

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
