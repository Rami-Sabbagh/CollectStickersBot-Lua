
# Dependencies

```bash
sudo luarocks install lua-telegram-bot lua-cjson lua-http cqueues LuaFileSystem ansicolors
```

- `lua-telegram-bot` for using Telegram's bots API.
- `lua-cjson` for reading and writing the bot's configuration files.
- `lua-http` to allow some modules to do http requests.
- `cqueue` for the bot to operante asynchronously internally.
- `LuaFileSystem` for the bot's storage system to work.
- `ansicolors` to give the bot's terminal output some colors.
