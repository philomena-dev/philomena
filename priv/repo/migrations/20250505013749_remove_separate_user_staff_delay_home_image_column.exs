defmodule Philomena.Repo.Migrations.RemoveSeparateUserStaffDelayHomeImageColumn do
  use Ecto.Migration

  def change do
    alter table("users") do
      # Remove the columns used in the old approach where we had two separate
      # columns for staff and non-staff users with different defaults.
      remove :staff_delay_home_images, :boolean, default: false
      remove :delay_home_images, :boolean, default: true

      # Now we have a single column that is nullable, where the default value is
      # calculated in the application code instead when this column is null.
      #
      # Technically, this migration would result in a data loss, but we haven't
      # yet pushed the previous migration to production, so this is safe to do,
      # as it only affects dev environments.
      add :delay_home_images, :boolean
    end
  end
end
