# Interactive commands

Any command can return a function which will be treated as the "Interactive Handler".

The handler function is like the following:

```lua
return function(update, overriden, previous)
    return unsubscribe
end
```

`update` is the update object the bot has recieved in the chat which the interactive command has been activated, and it can be nil in 2 cases:

- When the interative command has been just activated, `overriden` would be `nil` or `false` in this point, `previous` would be `true` if this interactive command overrided a previous one.
- When another interative command is overriding this one, there's no way to stop it, a good operation is to send a message about being cancelled successfully.

The interactive handler can return at any call `true` to "unsubscribe", which is in other words delete the interactive handler, as when it has finished, failed or cancelled.

When being overriden it's not necessary to return `true` because it's being deleted anyways.
