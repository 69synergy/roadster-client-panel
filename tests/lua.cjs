const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
module.exports = function runLua(source, globals = {}) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  for (const [name, value] of Object.entries(globals)) {
    lua.lua_pushstring(L, to_luastring(value));
    lua.lua_setglobal(L, to_luastring(name));
  }
  try {
    if (lauxlib.luaL_dostring(L, to_luastring(source)) !== lua.LUA_OK) {
      throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
    }
  } finally { lua.lua_close(L); }
};
