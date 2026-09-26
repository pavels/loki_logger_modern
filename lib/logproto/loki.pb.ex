defmodule LokiLoggerModern.Logproto.Direction do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :FORWARD, 0
  field :BACKWARD, 1
end

defmodule LokiLoggerModern.Logproto.PushRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :streams, 1, repeated: true, type: LokiLoggerModern.Logproto.StreamAdapter, deprecated: false
end

defmodule LokiLoggerModern.Logproto.PushResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule LokiLoggerModern.Logproto.QueryRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :selector, 1, type: :string
  field :limit, 2, type: :uint32
  field :start, 3, type: Google.Protobuf.Timestamp, deprecated: false
  field :end, 4, type: Google.Protobuf.Timestamp, deprecated: false
  field :direction, 5, type: LokiLoggerModern.Logproto.Direction, enum: true
  field :shards, 7, repeated: true, type: :string, deprecated: false
  field :deletes, 8, repeated: true, type: LokiLoggerModern.Logproto.Delete
end

defmodule LokiLoggerModern.Logproto.SampleQueryRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :selector, 1, type: :string
  field :start, 2, type: Google.Protobuf.Timestamp, deprecated: false
  field :end, 3, type: Google.Protobuf.Timestamp, deprecated: false
  field :shards, 4, repeated: true, type: :string, deprecated: false
  field :deletes, 5, repeated: true, type: LokiLoggerModern.Logproto.Delete
end

defmodule LokiLoggerModern.Logproto.Delete do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :selector, 1, type: :string
  field :start, 2, type: :int64
  field :end, 3, type: :int64
end

defmodule LokiLoggerModern.Logproto.QueryResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :streams, 1, repeated: true, type: LokiLoggerModern.Logproto.StreamAdapter, deprecated: false
  field :stats, 2, type: Stats.Ingester, deprecated: false
end

defmodule LokiLoggerModern.Logproto.SampleQueryResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :series, 1, repeated: true, type: LokiLoggerModern.Logproto.Series, deprecated: false
  field :stats, 2, type: Stats.Ingester, deprecated: false
end

defmodule LokiLoggerModern.Logproto.LabelRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :name, 1, type: :string
  field :values, 2, type: :bool
  field :start, 3, type: Google.Protobuf.Timestamp, deprecated: false
  field :end, 4, type: Google.Protobuf.Timestamp, deprecated: false
end

defmodule LokiLoggerModern.Logproto.RateLimitedStream do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :labels, 1, type: :string
end

defmodule LokiLoggerModern.Logproto.LabelResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :values, 1, repeated: true, type: :string
end

defmodule LokiLoggerModern.Logproto.StreamAdapter do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :labels, 1, type: :string, deprecated: false
  field :entries, 2, repeated: true, type: LokiLoggerModern.Logproto.EntryAdapter, deprecated: false
  field :hash, 3, type: :uint64, deprecated: false
end

defmodule LokiLoggerModern.Logproto.EntryAdapter do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :timestamp, 1, type: Google.Protobuf.Timestamp, deprecated: false
  field :line, 2, type: :string, deprecated: false
end

defmodule LokiLoggerModern.Logproto.Sample do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :timestamp, 1, type: :int64, deprecated: false
  field :value, 2, type: :double, deprecated: false
  field :hash, 3, type: :uint64, deprecated: false
end

defmodule LokiLoggerModern.Logproto.LegacySample do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :value, 1, type: :double
  field :timestamp_ms, 2, type: :int64, json_name: "timestampMs"
end

defmodule LokiLoggerModern.Logproto.Series do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :labels, 1, type: :string, deprecated: false
  field :samples, 2, repeated: true, type: LokiLoggerModern.Logproto.Sample, deprecated: false
  field :streamHash, 3, type: :uint64, deprecated: false
end

defmodule LokiLoggerModern.Logproto.TailRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :query, 1, type: :string
  field :delayFor, 3, type: :uint32
  field :limit, 4, type: :uint32
  field :start, 5, type: Google.Protobuf.Timestamp, deprecated: false
end

defmodule LokiLoggerModern.Logproto.TailResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :stream, 1, type: LokiLoggerModern.Logproto.StreamAdapter, deprecated: false
  field :droppedStreams, 2, repeated: true, type: LokiLoggerModern.Logproto.DroppedStream
end

defmodule LokiLoggerModern.Logproto.SeriesRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :start, 1, type: Google.Protobuf.Timestamp, deprecated: false
  field :end, 2, type: Google.Protobuf.Timestamp, deprecated: false
  field :groups, 3, repeated: true, type: :string
  field :shards, 4, repeated: true, type: :string, deprecated: false
end

defmodule LokiLoggerModern.Logproto.SeriesResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :series, 1, repeated: true, type: LokiLoggerModern.Logproto.SeriesIdentifier, deprecated: false
end

defmodule LokiLoggerModern.Logproto.SeriesIdentifier.LabelsEntry do
  @moduledoc false
  use Protobuf, map: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule LokiLoggerModern.Logproto.SeriesIdentifier do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :labels, 1, repeated: true, type: LokiLoggerModern.Logproto.SeriesIdentifier.LabelsEntry, map: true
end

defmodule LokiLoggerModern.Logproto.DroppedStream do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :from, 1, type: Google.Protobuf.Timestamp, deprecated: false
  field :to, 2, type: Google.Protobuf.Timestamp, deprecated: false
  field :labels, 3, type: :string
end

defmodule LokiLoggerModern.Logproto.TimeSeriesChunk do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :from_ingester_id, 1, type: :string, json_name: "fromIngesterId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :labels, 3, repeated: true, type: LokiLoggerModern.Logproto.LabelPair
  field :chunks, 4, repeated: true, type: LokiLoggerModern.Logproto.Chunk
end

defmodule LokiLoggerModern.Logproto.LabelPair do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :name, 1, type: :string
  field :value, 2, type: :string
end

defmodule LokiLoggerModern.Logproto.LegacyLabelPair do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :name, 1, type: :bytes
  field :value, 2, type: :bytes
end

defmodule LokiLoggerModern.Logproto.Chunk do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :data, 1, type: :bytes
end

defmodule LokiLoggerModern.Logproto.TransferChunksResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule LokiLoggerModern.Logproto.TailersCountRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
end

defmodule LokiLoggerModern.Logproto.TailersCountResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :count, 1, type: :uint32
end

defmodule LokiLoggerModern.Logproto.GetChunkIDsRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :matchers, 1, type: :string
  field :start, 2, type: Google.Protobuf.Timestamp, deprecated: false
  field :end, 3, type: Google.Protobuf.Timestamp, deprecated: false
end

defmodule LokiLoggerModern.Logproto.GetChunkIDsResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :chunkIDs, 1, repeated: true, type: :string
end

defmodule LokiLoggerModern.Logproto.ChunkRef do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :fingerprint, 1, type: :uint64, deprecated: false
  field :user_id, 2, type: :string, json_name: "userId", deprecated: false
  field :from, 3, type: :int64, deprecated: false
  field :through, 4, type: :int64, deprecated: false
  field :checksum, 5, type: :uint32, deprecated: false
end

defmodule LokiLoggerModern.Logproto.LabelValuesForMetricNameRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :metric_name, 1, type: :string, json_name: "metricName"
  field :label_name, 2, type: :string, json_name: "labelName"
  field :from, 3, type: :int64, deprecated: false
  field :through, 4, type: :int64, deprecated: false
  field :matchers, 5, type: :string
end

defmodule LokiLoggerModern.Logproto.LabelNamesForMetricNameRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :metric_name, 1, type: :string, json_name: "metricName"
  field :from, 2, type: :int64, deprecated: false
  field :through, 3, type: :int64, deprecated: false
end

defmodule LokiLoggerModern.Logproto.GetChunkRefRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :from, 1, type: :int64, deprecated: false
  field :through, 2, type: :int64, deprecated: false
  field :matchers, 3, type: :string
end

defmodule LokiLoggerModern.Logproto.GetChunkRefResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :refs, 1, repeated: true, type: LokiLoggerModern.Logproto.ChunkRef
end

defmodule LokiLoggerModern.Logproto.GetSeriesRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :from, 1, type: :int64, deprecated: false
  field :through, 2, type: :int64, deprecated: false
  field :matchers, 3, type: :string
end

defmodule LokiLoggerModern.Logproto.GetSeriesResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :series, 1, repeated: true, type: LokiLoggerModern.Logproto.IndexSeries, deprecated: false
end

defmodule LokiLoggerModern.Logproto.IndexSeries do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :labels, 1, repeated: true, type: LokiLoggerModern.Logproto.LabelPair, deprecated: false
end

defmodule LokiLoggerModern.Logproto.QueryIndexResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :QueryKey, 1, type: :string
  field :rows, 2, repeated: true, type: LokiLoggerModern.Logproto.Row
end

defmodule LokiLoggerModern.Logproto.Row do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :rangeValue, 1, type: :bytes
  field :value, 2, type: :bytes
end

defmodule LokiLoggerModern.Logproto.QueryIndexRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :Queries, 1, repeated: true, type: LokiLoggerModern.Logproto.IndexQuery
end

defmodule LokiLoggerModern.Logproto.IndexQuery do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :tableName, 1, type: :string
  field :hashValue, 2, type: :string
  field :rangeValuePrefix, 3, type: :bytes
  field :rangeValueStart, 4, type: :bytes
  field :valueEqual, 5, type: :bytes
end

defmodule LokiLoggerModern.Logproto.IndexStatsRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :from, 1, type: :int64, deprecated: false
  field :through, 2, type: :int64, deprecated: false
  field :matchers, 3, type: :string
end

defmodule LokiLoggerModern.Logproto.IndexStatsResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :streams, 1, type: :uint64, deprecated: false
  field :chunks, 2, type: :uint64, deprecated: false
  field :bytes, 3, type: :uint64, deprecated: false
  field :entries, 4, type: :uint64, deprecated: false
end