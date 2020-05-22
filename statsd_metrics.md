
# Bot's StatsD Metrics

> All metrices are prefixed with the namespace `bot.`

## Stickers

### Stickers processing

- `modules.stickers.process.success,type=animated` - (Counter) Processed animated stickers count.
- `modules.stickers.process.success,type=static` - (Counter) Processed static stickers count.
- `modules.stickers.process.success,type=mask` - (Counter) Processed mask stickers count.
- `modules.stickers.process.failure,stage=download,reason=<reason>` - (Counter) Stickers failed to be processed due to download failure.
- `modules.stickers.process.failure,stage=new,reason=<reason>` - (Counter) Stickers failed to be processed due to failure in creating a new set for them.
- `modules.stickers.process.failure,stage=add,reason=<reason>` - (Counter) Stickers failed to be processed due to failure in adding them to an existing set.

### Stickers workers

- `modules.stickers.worker,action=started` - (Counter) Stickers workers started count.
- `modules.stickers.worker,action=finished` - (Counter) Stickers workers finished count.
- `modules.stickers.worker.error` - (Counter) Stickers workers errored count.
- `modules.stickers.worker.active` - (Gauge) The current number of active stickers workers.

### Stickers handler

- `modules.stickers.handler,action=invalid` - (Counter) Invalid messages count.
- `modules.stickers.handler,action=full` - (Counter) The number of stickers which have been rejected due to the work queue being full.
- `modules.stickers.handler,action=success` - (Counter) The number of times which the stickers counter worked fine.

## Commands

### User commands

- `commands.processed` - (Counter) The total number of text messages starting with a `/` processed.
- `commands.time,visibility=<public/hidden>,name=<command_name>` - (Timer) Command execution time.
- `commands.success,visibility=<public/hidden>,name=<command_name>` - (Counter) Commands executed successfully count.
- `commands.failure,visibility=<public/hidden>,name=<command_name>` - (Counter) Commands failed in their execution count.
- `commands.invalid,name=<command_name>` - (Counter) Unknown commands execution count.

### Developer commands

- `modules.developer.authorized,method=<method>` - (Counter) The number of times a developer got authorized (`password, username`).
- `modules.developer.deauthorized` - (Counter) The number of times a developer deauthorized
- `modules.developer.attempted` - (Counter) The number of times someone failed to authorize as developer.
- `modules.developer.fooled,name=<command_name>` - (Counter) The number of times soneone unauthorized attempted to use a developer command.

## Updates

- `updates.processed.total` - (Counter) The total number of telegram updates processed.
- `updates.processed,type=<type>` - (Counter) The number of updates with a specific type processed (`other, message, edited_message, channel_post, edited_channel_post`).
- `updates.delta` - (Gauge) The delta time between each 2 updates processed.
- `updates.polling.delta` - (Gauge) The delta time between the last update batch and the previous one.
- `updates.polling.count` - (Gauge) The number of updates received in the batch.
- `updates.polling.total` - (Counter) The total number of updates received.
- `updates.polling.failed` - (Counter) The number of times the bot failed to poll updates.

## Storage

- `storage.container,action=new` - (Counter) The number of new containers created.
- `storage.file,action=new` - (Counter) The number of new files created with no existing data.
- `storage.file,action=load` - (Counter) Files loaded with existing data count.
- `storage.file,action=save` - (Counter) Files saved.

## Logging

- `logger.newlogfile` - (Counter) New log file requests count.
- `logger.log.<level>` - (Counter) (`title, loading, subloading, colored, prompt, critical, error, warn, info, debug, trace`).

## Bot

- `bot.ready` - (Counter) The number of times the bot got ready.
- `bot.exit,reason=<shutdown/restart/upgrade/crash>` - (Counter) The number of times the bot has exited.
- `bot.cque.count` - (Gauge) The number of controllers in the main bot cqueue.

## Telegram

- `telegram.request.letancy,method=<method>` - (Gauge) The time a request has took.
- `telegram.request.failure,method=<method>` - (Counter) Telegram requests failure count.
