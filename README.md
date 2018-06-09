# LdapEcto

**Ecto Adapter for LDAP**

Supporting create, update, delete and search (CRUD).

Migrations or Constraints are not working yet.

## Installation

[From GitHub](https://github.com/vog3l/ldap_ecto), the package can be installed as follows:

  1. Add `ldap_ecto` to your list of dependencies in `mix.exs`:
```elixir
        def deps do
          [
            {:ldap_ecto, git: "http://github.com:vog3l/ldap_ecto.git", tag: "0.2"},
          ]
        end
```

  2. Specify `Ldap.Ecto.Adapter` as the adapter for your application's Repo:
```elixir
    config :my_app, MyApp.Repo,
      adapter: Ldap.Ecto.Adapter,
      hostname: "ldap.example.com",
      base: "dc=example,dc=com",
      port: 636,
      ssl: true,
      user_dn: "uid=sample_user,ou=users,dc=example,dc=com",
      password: "password",
      # search scope: [ "baseObject", "singleLevel", "wholeSubtree" ]
      scope: "singleLevel",
      pool_size: 1
```

## Usage

Use the `ldap_ecto` adapter, almost as you would any other Ecto backend.
You have to specify the primary_key and dn field. The primary_key can be any available attribute.
On creation of a new entry the dn is derived from the primary_key, the schema and the base_dn.

### Example Schema


```elixir
        defmodule User do
          use Ecto.Schema
          import Ecto.Changeset

          @derive {Phoenix.Param, key: :uid}
          @primary_key {:uid, :string, autogenerate: false}
          schema "ou=users" do
            field :dn, :string  # mandatory
            field :objectClass, {:array, :string}, default: ["top", "person", "inetorgperson"]
            field :mail, :string
            field :alias, {:array, :string}
            field :sn, :string
            field :cn, :string
          end

          @doc false
          def changeset(%User{} = user, attrs) do
            user
            |> cast(attrs, [:uid, :mail, :alias, :cn, :sn, :objectClass])
            |> unique_constraint(:uid)
            |> unique_constraint(:mail)
            |> validate_required([:uid, :objectClass])
          end

          @doc false
          def create_changeset(%User{} = user, attrs) do
            user
            |> cast(attrs, [:uid, :mail, :alias, :cn, :sn, :objectClass])
            |> unique_constraint(:uid)
            |> unique_constraint(:mail)
            |> validate_required([:uid, :objectClass])
          end

        end
```

```elixir
        defmodule Group do
          use Ecto.Schema
          import Ecto.Changeset

          @derive {Phoenix.Param, key: :cn}
          @primary_key {:cn, :string, autogenerate: false}
          schema "ou=groups" do
            field :dn, :string
            field :objectClass, {:array, :string}, default: ["top", "groupofuniquenames"]
            field :ou, :string
            field :description, :string
            field :uniqueMember, {:array, :string}
          end

          @doc false
          def changeset(%Group{} = group, attrs) do
            group
            |> cast(attrs, [:cn, :ou, :description, :uniqueMember, :objectClass])
            |> unique_constraint(:cn)
            |> validate_required([:cn, :objectClass])
          end

          @doc false
          def create_changeset(%Group{} = group, attrs) do
            group
            |> cast(attrs, [:cn, :ou, :description, :uniqueMember, :objectClass])
            |> unique_constraint(:cn)
            |> validate_required([:cn, :objectClass])
          end
        end
```

### Example Queries

```elixir
        Repo.get User, "testuser"

        Repo.get_by User, mail: "testuser@example.com"

        Repo.all User, st: "OR"

        Repo.insert User

        Repo.update User

        Repo.delete User

        Ecto.Query.from(u in User, where: like(u.mail, "%@example.com"))

        Ecto.Query.from(u in User, where: "inetOrgPerson" in u.objectClass and not is_nil(u.mail), select: u.uid)
```
