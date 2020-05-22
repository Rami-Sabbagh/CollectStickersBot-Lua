
# Bot's StatsD Metrics

> All metrices are prefixed with the namespace `bot.`

## Stickers

### Stickers processing

- `modules.stickers.process.animated` - (Counter) Processed animated stickers count.
- `modules.stickers.process.static` - (Counter) Processed static stickers count.
- `modules.stickers.process.mask` - (Counter) Processed mask stickers count.
- `modules.stickers.process.failure.download.<reason>` - (Counter) Stickers failed to be processed due to download failure.
- `modules.stickers.process.failure.new.<reason>` - (Counter) Stickers failed to be processed due to failure in creating a new set for them.
- `modules.stickers.process.failure.add.<reason>` - (Counter) Stickers failed to be processed due to failure in adding them to an existing set.

### Stickers workers

- `modules.stickers.worker.started` - (Counter) Stickers workers started count.
- `modules.stickers.worker.finished` - (Counter) Stickers workers finished count.
- `modules.stickers.worker.error` - (Counter) Stickers workers errored count.
- `modules.stickers.worker.active` - (Gauge) The current number of active stickers workers.

### Stickers handler

- `modules.stickers.handler.invalid` - (Counter) Invalid messages count.
- `modules.stickers.handler.full` - (Counter) The number of stickers which have been rejected due to the work queue being full.
- `modules.stickers.handler.success` - (Counter) The number of times which the stickers counter worked fine.

## Commands

### User commands

- `commands.processed` - (Counter) The total number of text messages starting with a `/` processed.
- `commands.success.<public/hidden>.<command_name>` - (Counter) Commands executed successfully count.
- `commands.failure.<public/hidden>.<command_name>` - (Counter) Commands failed in their execution count.
- `commands.invalid.<command_name>` - (Counter) Unknown commands execution count.

### Developer commands

- `commands.developer.authorized` - (Counter) The number of times a developer got authorized.
- `commands.developer.unauthorized` - (Counter) The number of times a developer deauthorized
- `commands.developer.attempted` - (Counter) The number of times someone failed to authorize as developer.
- `commands.developer.fooled` - (Counter) The number of times soneone unauthorized attempted to use a developer command.

## Updates

- `updates.processed` - (Counter) The total number of telegram updates processed.
- `updates.processed.<type>` - (Counter) The number of updates with a specific type processed (`other, message, edited_message, channel_post, edited_channel_post`).
- `updates.delta` - (Timer) The delta time between each 2 updates processed.
- `updates.polling.delta` - (Timer) The delta time between the last update batch and the previous one.
- `updates.polling.count` - (Gauge) The number of updates received in the batch.
- `updates.polling.total` - (Counter) The total number of updates received.
- `updates.polling.failed.<reason>` - (Counter) The number of times the bot failed to poll updates.

## Storage

- `storage.container.new` - (Counter) The number of new containers created.
- `storage.file.new` - (Counter) The number of new files created with no existing data.
- `storage.file.load` - (Counter) Files loaded with existing data count.
- `storage.file.save` - (Counter) Files saved.

## Logging

- `logger.newlogfile` - (Counter) New log file requests count.
- `logger.log.<level>` - (Counter) (`title, loading, subloading, colored, prompt, critical, error, warn, info, debug, trace`).

## Bot

- `bot.ready` - (Counter) The number of times the bot got ready.
- `bot.exit.<shutdown/restart/upgrade/crash>` - (Counter) The number of times the bot has exited.
- `bot.cque.count` - (Gauge) The number of controllers in the main bot cqueue.
