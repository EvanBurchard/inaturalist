require File.dirname(__FILE__) + '/../spec_helper.rb'

describe List, "updating" do
  it "should not be allowed anyone other than the owner" do
    list = LifeList.make
    other_user = User.make
    list.should be_editable_by list.user
    list.should_not be_editable_by other_user
  end
end

# Note: List#refresh is pretty thoroughly tested by the Observation 
# spec, so these will remain unimplemented.  I couldn't figure out how to
# test them without touching observations anyway (KMU 2008-12-5)
describe List, "refreshing" do
  it "should update all last_observations in the list"
  it "should destroy all invalid listed taxa"
  it "should restrict its updates to the taxa param passed in"
end

describe List, "taxon adding" do
  
  it "should return a ListedTaxon" do
    list = List.make
    taxon = Taxon.make
    list.add_taxon(taxon).should be_a(ListedTaxon)
  end
  
  it "should not create a new ListedTaxon if the taxon is already in the list" do
    listed_taxon = ListedTaxon.make
    list = listed_taxon.list
    taxon = listed_taxon.taxon
    new_listed_taxon = list.add_taxon(taxon)
    new_listed_taxon.should_not be_valid
  end
  
end
