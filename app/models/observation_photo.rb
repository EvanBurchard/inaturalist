class ObservationPhoto < ActiveRecord::Base
  belongs_to :observation, :inverse_of => :observation_photos, :counter_cache => false
  belongs_to :photo
  
  after_create :set_observation_quality_grade,
               :set_observation_photos_count
  after_destroy :destroy_orphan_photo, :set_observation_quality_grade, :set_observation_photos_count
  
  def destroy_orphan_photo
    Photo.delay.destroy_orphans(photo_id)
    true
  end
  
  # Might be better to do this with DJ...
  def set_observation_quality_grade
    return true unless observation
    Observation.delay.set_quality_grade(observation.id)
    true
  end

  def set_observation_photos_count
    if o = Observation.find_by_id(observation_id)
      Observation.update_all(["photos_count = ?", o.observation_photos.count], ["id = ?", o.id])
    end
    true
  end
  
end
