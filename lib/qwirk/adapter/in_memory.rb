require 'qwirk/adapter/in_memory/factory'
require 'qwirk/adapter/in_memory/publisher'
require 'qwirk/adapter/in_memory/queue'
require 'qwirk/adapter/in_memory/reply_queue'
require 'qwirk/adapter/in_memory/topic'
require 'qwirk/adapter/in_memory/worker_config'
require 'qwirk/adapter/in_memory/worker'

::Qwirk.register_adapter(
    :in_memory,
    ::Qwirk::Adapter::InMemory::Publisher,
    ::Qwirk::Adapter::InMemory::WorkerConfig
)
