class CreatePipelineTables < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :pipeline_instances do |t|
      t.string  :type                    # For single table inheritance
      t.string  :status                  # Current status of the pipeline
      t.integer :attempts, default: 0    # Number of times this pipeline was executed
      t.references :external             # External object association (user-defined)

      t.timestamps
    end

    create_table :pipeline_stages do |t|
      t.references :pipeline_instance    # Pipeline that holds this stage
      t.string     :type                 # For single table inheritance
      t.string     :name                 # Name of the stage
      t.string     :status               # Current status of the stage
      t.text       :message              # Message that describes current status
      t.integer    :attempts, default: 0 # Number of times this stage was executed

      t.timestamps
    end
  end
end
