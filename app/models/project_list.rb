class ProjectList < LifeList
  belongs_to :project
  validates_presence_of :project_id
  
  def owner
    project
  end
  
  def owner_name
    project.title
  end
  
  def listed_taxa_editable_by?(user)
    return false if user.blank?
    project.project_users.exists?(:user_id => user)
  end
  
  # Curators and admins can alter the list.
  def editable_by?(user)
    return false if user.blank?
    project.project_users.exists?(:role => "curator", :user_id => user)
  end
  
  def cache_columns_query_for(lt)
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt
    sql_key = "EXTRACT(month FROM observed_on) || substr(quality_grade,1,1)"
    <<-SQL
      SELECT
        array_agg(o.id) AS ids,
        count(*),
        (#{sql_key}) AS key
      FROM
        observations o
          LEFT OUTER JOIN taxa t ON t.id = o.taxon_id
          LEFT OUTER JOIN project_observations po ON po.observation_id = o.id
      WHERE
        po.project_id = #{project_id} AND
        (
          o.taxon_id = #{lt.taxon_id} OR 
          t.ancestry LIKE '#{lt.taxon.ancestry}/%'
        )
      GROUP BY #{sql_key}
    SQL
  end
  
  private
  def set_defaults
    self.title ||= "%s's Check List" % owner_name
    self.description ||= "The species list for #{owner_name}"
    true
  end
end
