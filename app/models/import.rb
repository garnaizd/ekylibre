# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2015 Brice Texier, David Joulin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: imports
#
#  archive_content_type   :string
#  archive_file_name      :string
#  archive_file_size      :integer
#  archive_updated_at     :datetime
#  created_at             :datetime         not null
#  creator_id             :integer
#  id                     :integer          not null, primary key
#  imported_at            :datetime
#  importer_id            :integer
#  lock_version           :integer          default(0), not null
#  nature                 :string           not null
#  progression_percentage :decimal(19, 4)
#  state                  :string           not null
#  updated_at             :datetime         not null
#  updater_id             :integer
#

class Import < Ekylibre::Record::Base
  belongs_to :importer, class_name: 'User'
  refers_to :nature, class_name: 'ExchangeNature'
  enumerize :state, in: [:undone, :in_progress, :errored, :aborted, :finished], predicates: true, default: :undone
  has_attached_file :archive, path: ':tenant/:class/:id/:style.:extension'
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates_datetime :archive_updated_at, :imported_at, allow_blank: true, on_or_after: Time.new(1, 1, 1, 0, 0, 0, '+00:00')
  validates_numericality_of :archive_file_size, allow_nil: true, only_integer: true
  validates_numericality_of :progression_percentage, allow_nil: true
  validates_presence_of :nature, :state
  # ]VALIDATORS]
  validates_inclusion_of :progression_percentage, in: 0..100, allow_blank: true
  do_not_validate_attachment_file_type :archive

  class InterruptRequest < StandardError
  end

  class << self
    # Create an import and run it in background
    def launch(nature, file)
      f = File.open(file)
      import = create!(nature: nature, archive: f)
      ImportRunJob.perform_later(import.id)
      import
    end

    # Create an import and run it directly
    def launch!(nature, file, &block)
      f = File.open(file)
      import = create!(nature: nature, archive: f)
      import.run(&block)
      import
    end
  end

  def name
    nature ? nature.text : :unknown.tl
  end

  def run_later
    ImportRunJob.perform_later(id)
  end

  # Run an import.
  # The optional code block permit have access to progression on each check point
  def run
    FileUtils.mkdir_p(progress_file.dirname)
    update_columns(state: :in_progress, progression_percentage: 0)
    File.write(progress_file, 0.to_s)
    Ekylibre::Record::Base.transaction do
      ActiveExchanger::Base.import(nature.to_sym, archive.path) do |progression, count|
        update_columns(progression_percentage: progression)
        fail InterruptRequest unless File.exist? progress_file
        File.write(progress_file, progression.to_i.to_s)
        break if block_given? && !yield(progression, count)
      end
    end
    fail InterruptRequest unless File.exist? progress_file
    update_columns(state: :finished, progression_percentage: 100, imported_at: Time.zone.now, importer_id: (User.stamper.is_a?(User) ? User.stamper.id : User.stamper.is_a?(Fixnum) ? User.stamper : nil))
  end

  def progress_file
    Ekylibre::Tenant.private_directory.join('tmp', 'imports', "#{id}.progress")
  end

  def progress
    File.read(progress_file).to_i
  rescue
    0
  end

  def runnable?
    self.undone? && archive.file?
  end

  # Removing progress is the signal to interrupt the process
  def abort
    FileUtils.rm_rf(progress_file)
    update_column(:state, :aborted)
  end

  def notify(message, interpolations = {}, options = {})
    if creator
      creator.notify(message, interpolations.merge(name: name), options.merge(target: self))
    end
  end
end
