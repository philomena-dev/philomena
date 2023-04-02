defmodule Philomena.Repo.Migrations.AddWeb3Tables do
  use Ecto.Migration

  def change do

    alter table("users") do
      add :ethereum, :varchar, null: false, default: ""
    end

    execute("ALTER TABLE public.users
    ADD COLUMN last_ethereum_renamed_at timestamp without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL;")

    execute(
      "CREATE TABLE public.ethereum_changes (
        id integer NOT NULL,
        user_id bigint NOT NULL,
        ethereum character varying NOT NULL,
        sign_data character varying NOT NULL,
        created_at timestamp without time zone NOT NULL,
        updated_at timestamp without time zone NOT NULL
    )"
    )

    execute(
      "CREATE SEQUENCE public.ethereum_changes_id_seq
      START WITH 1
      INCREMENT BY 1
      NO MINVALUE
      NO MAXVALUE
      CACHE 1;"
    )

    execute(
      "ALTER TABLE ONLY public.ethereum_changes ALTER COLUMN id SET DEFAULT nextval('public.ethereum_changes_id_seq'::regclass);"
    )

    execute(
      "ALTER TABLE ONLY public.ethereum_changes ADD CONSTRAINT ethereum_changes_pkey PRIMARY KEY (id);"
    )

    execute(
      "CREATE INDEX index_ethereum_changes_on_user_id ON public.ethereum_changes USING btree (user_id);"
    )

    execute("ALTER TABLE public.commission_items
    ADD COLUMN currency character varying DEFAULT 'USD' NOT NULL,
    ADD COLUMN allow_crypto boolean DEFAULT false NOT NULL;")

    execute("ALTER TABLE public.commissions
    ADD COLUMN currencies character varying[] DEFAULT '{USD}' NOT NULL,
    ADD COLUMN allow_crypto boolean DEFAULT false NOT NULL;")

  end
end
