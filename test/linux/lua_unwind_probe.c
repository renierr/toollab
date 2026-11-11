#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>

typedef struct lua_State lua_State;

__attribute__((constructor)) static void check_lua_unwind(void) {
  void *lua = dlopen("libluajit-5.1.so.2", RTLD_NOW | RTLD_GLOBAL);
  if (!lua) {
    dprintf(2, "Cannot load LuaJIT: %s\n", dlerror());
    _exit(2);
  }
  lua_State *(*newstate)(void) = dlsym(lua, "luaL_newstate");
  void (*openlibs)(lua_State *) = dlsym(lua, "luaL_openlibs");
  int (*loadstring)(lua_State *, const char *) = dlsym(lua, "luaL_loadstring");
  int (*pcall)(lua_State *, int, int, int) = dlsym(lua, "lua_pcall");
  if (!newstate || !openlibs || !loadstring || !pcall) _exit(2);

  lua_State *state = newstate();
  if (!state) _exit(2);
  openlibs(state);
  if (loadstring(state, "error('expected test error')")) _exit(2);
  int result = pcall(state, 0, 0, 0);
  dprintf(2, "Lua error returned %d (expected 2)\n", result);
  _exit(result == 2 ? 0 : 1);
}
