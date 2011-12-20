#
# A LifeList is a List of all the taxa a person has observed.
#
class LifeList < List
  before_validation :set_defaults
  after_create :add_taxa_from_observations
  
  MAX_RELOAD_TRIES = 15
  
  #
  # Adds a taxon to this life list by creating a new blank obs of the taxon
  # and relying on the callbacks in observation.  In theory, this should never
  # bonk on an invalid listed taxon...
  #
  def add_taxon(taxon, options = {})
    taxon_id = taxon.is_a?(Taxon) ? taxon.id : taxon
    if listed_taxon = listed_taxa.find_by_taxon_id(taxon_id)
      return listed_taxon
    end
    ListedTaxon.create(options.merge(:list => self, :taxon_id => taxon_id))
  end
  
  #
  # Update all the taxa in this list, or just a select few.  If taxa have no
  # longer been observed, they will be deleted.  If they have been more
  # recently observed, their last_observation will be updated.  If taxa were
  # selected that were not in the list, they will be added if they've been
  # observed.
  #
  def refresh(options = {})
    if taxa = options[:taxa]
      # Find existing listed_taxa of these taxa to update
      existing = ListedTaxon.all(:conditions => ["list_id = ? AND taxon_id IN (?)", self, taxa])
      collection = []
      
      # Add new listed taxa for taxa not already on this list
      if options[:add_new_taxa]
        taxa_ids = taxa.map do |taxon|
          if taxon.is_a?(Taxon)
            taxon.id
          elsif taxon.is_a?(Fixnum)
            taxon
          else
            nil
          end
        end.compact
        
        # Create new ListedTaxa for the taxa that aren't already in the list
        collection = (taxa_ids - existing.map(&:taxon_id)).map do |taxon_id|
          listed_taxon = ListedTaxon.new(:list => self, :taxon_id => taxon_id)
          listed_taxon.skip_update = true
          listed_taxon
        end
      end
      collection += existing
    else
      collection = self.listed_taxa
    end

    collection.each do |listed_taxon|
      # re-apply list rules to the listed taxa
      unless listed_taxon.save
        logger.debug "[DEBUG] #{listed_taxon} wasn't valid in #{self}, so " + 
          "it's being destroyed: #{listed_taxon.errors.full_messages.to_sentence}"
        listed_taxon.destroy
      end
      
      if options[:destroy_unobserved] && 
          listed_taxon.last_observation.try(:taxon_id) != listed_taxon.taxon_id
        listed_taxon.destroy
      end
    end
    true
  end
  
  # Add all the taxa the list's owner has observed.  Cache the job ID so we 
  # can display a loading notification on lists/show.
  def add_taxa_from_observations
    job = LifeList.send_later(:add_taxa_from_observations, self)
    Rails.cache.write(add_taxa_from_observations_key, job.id)
    true
  end
  
  def add_taxa_from_observations_key
    "add_taxa_from_observations_job_#{id}"
  end
  
  def self.add_taxa_from_observations(list, options = {})
    conditions = if options[:taxa]
      ["taxon_id IN (?)", options[:taxa]]
    else
      'taxon_id IS NOT NULL'
    end
    # Note: this should use find_each, but due to a bug in rails < 3,
    # conditions in find_each get applied to scopes utilized by anything
    # further up the call stack, causing bugs.
    list.owner.observations.all(
        :select => 'DISTINCT ON(observations.taxon_id) observations.id, observations.taxon_id', 
        # :group => 'observations.taxon_id', 
        :conditions => conditions).each do |observation|
      list.add_taxon(observation.taxon_id, 
        :last_observation_id => observation.id,
        :skip_update => true)
    end
  end
  
  # def self.remove_unobserved(list, options = {})
  #   list.listed_taxa.find_each(:include => :last_observation) do |listed_taxon|
  #     if listed_taxon.last_observation.blank? || listed_taxon.taxon_id != listed_taxon.last_observation.taxon_id
  #       listed_taxon.destroy
  #     end
  #   end
  # end
  
  def self.update_life_lists_for_taxon(taxon)
    ListRule.find_each(:include => :list, :conditions => [
      "operator LIKE 'in_taxon%' AND operand_type = ? AND operand_id IN (?)", 
      Taxon.to_s, taxon.self_and_ancestors.map(&:id)
    ]) do |list_rule|
      next unless list_rule.list.is_a?(LifeList)
      LifeList.send_later(:add_taxa_from_observations, list_rule.list, 
        :taxa => [taxon.id])
    end
  end
  
  def reload_from_observations
    job = LifeList.send_later(:reload_from_observations, self)
    Rails.cache.write(reload_from_observations_cache_key, job.id)
    job
  end
  
  def reload_from_observations_cache_key
    "reload_list_from_obs_#{id}"
  end
  
  def self.reload_from_observations(list)
    repair_observed(list)
    add_taxa_from_observations(list)
  end
  
  def self.repair_observed(list)
    list.listed_taxa.find_each(:include => :last_observation, 
        :conditions => "observations.id IS NOT NULL AND observations.taxon_id != listed_taxa.taxon_id") do |lt|
      lt.destroy
    end
  end
  
  private
  def set_defaults
    self.title ||= "%s's Life List" % owner_name
    self.description ||= "Every species seen by #{owner_name}"
    true
  end
end
