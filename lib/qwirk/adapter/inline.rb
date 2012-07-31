require 'qwirk/adapter/inline/publisher'
require 'qwirk/adapter/inline/worker_config'
require 'qwirk/adapter/inline/worker'

::Qwirk.register_adapter(
    :inline,
    ::Qwirk::Adapter::Inline::Publisher,
    ::Qwirk::Adapter::Inline::WorkerConfig
)
