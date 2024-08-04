defmodule PhilomenaJob.Jobs.Job do
  @moduledoc """
  Base schema module for processing jobs.
  """

  @doc false
  defmacro __using__ do
    quote do
      use Ecto.Schema
    end
  end

  @doc """
  Defines custom schema fields for processing jobs.

  Processing jobs have three default fields, which are created automatically
  by the `job_schema/2` macro and should not be redefined:
  - `:request_time`
  - `:attempt_count`
  - `:worker_name`

  The client should define the primary key and any additional fields.

  ## Examples

      defmodule Philomena.Images.IndexRequest do
        use Philomena.Jobs.Job

        job_schema "image_index_requests" do
          belongs_to Philomena.Images.Image, primary_key: true
          field :index_type, :string, default: "update"
        end
      end

      defmodule Philomena.Images.StorageRequest do
        use Philomena.Jobs.Job

        job_schema "image_storage_requests" do
          belongs_to Philomena.Images.Image, primary_key: true
          field :operation, :string, default: "put"
          field :key, :string
          field :data, :blob
        end
      end

  """
  defmacro job_schema(name, do: block) do
    quote do
      schema unquote(name) do
        field :request_time, :utc_datetime_usec
        field :attempt_count, :integer
        field :worker_name, :string

        unquote(block)
      end
    end
  end
end
