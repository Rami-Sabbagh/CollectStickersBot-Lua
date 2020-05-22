
# CollectStickersBot

A telegram bot for cloning stickers into your own stickers packs (collections)

## Installation

> Please the due to lua-telegram-bot's dependency on cqueues the bot wont be able to run on Windows system, except if run under WSL (Windows Subsystem Linux) which has been used during the whole development of the bot and the library.

The bot requires `luajit` and some Lua libraries to be installed using `luarocks`

### Installation of luajit and luarocks

```bash
sudo apt install build-essential m4 luajit luarocks
```

### Installation of the Lua libraries

```bash
sudo luarocks install --server=https://luarocks.dev lua-telegram-bot
sudo luarocks install lua-cjson lua-http cqueue LuaFileSystem ansicolors statsd
```

> If cqueues fails to build that might be due to `m4` not being installed, try to install it using `sudo apt install m4`.

### Configuration of the bot

Create a new telegram bot by using @BotFather, the start the bot by typing:

```bash
luajit ./start_upgradable.lua
```

When starting the bot for the first time, it'll ask for the bot's token, the timeout configuration, the developer username, and the developer password.

- The bot token is the one provided by bot father.
- Leave the requests timeout on it's default.
- The polling timeout can be increased into 60 if the system has a stable internet connection, increasing this values makes the bot less sensible to zombied connections.
- The developer username is the username of a Telegram user who will be given developer access as `/developer` is sent by him.
- The developer password can be used to authorize other Telegram users to have the developer's power, they can do so by sending `/developer <developer_password>`.

### Stopping the bot

- Authorize to the bot by sending it `/developer` on Telegram.
- Send `/shutdown` to shutdown the bot.
