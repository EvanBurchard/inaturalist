require File.dirname(__FILE__) + '/../spec_helper'

describe TaxaController do
  describe "merge" do
    it "should redirect on succesfully merging" do
      user = make_curator
      keeper = Taxon.make!
      reject = Taxon.make!
      sign_in user
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      response.should be_redirect
    end

    it "should allow curators to merge taxa they created" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!(:creator => curator)
      reject = Taxon.make!(:creator => curator)
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      Taxon.find_by_id(reject.id).should be_blank
    end

    it "should not allow curators to merge taxa they didn't create" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!(:creator => curator)
      reject = Taxon.make!
      Observation.make!(:taxon => reject)
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      Taxon.find_by_id(reject.id).should_not be_blank
    end

    it "should allow curators to merge synonyms" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!(:name => "Foo")
      reject = Taxon.make!(:name => "Foo")
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      Taxon.find_by_id(reject.id).should be_blank
    end

    it "should not allow curators to merge unsynonymous taxa" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!
      reject = Taxon.make!
      Observation.make!(:taxon => reject)
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      Taxon.find_by_id(reject.id).should_not be_blank
    end

    it "should allow curators to merge taxa without observations" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!
      reject = Taxon.make!
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      Taxon.find_by_id(reject.id).should be_blank
    end

    it "should allow admins to merge anything" do
      curator = make_admin
      sign_in curator
      keeper = Taxon.make!
      reject = Taxon.make!
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      Taxon.find_by_id(reject.id).should be_blank
    end
  end

  describe "destroy" do
    it "should not be possible unless user created the record" do
      u = make_curator
      sign_in u
      t = Taxon.make!
      delete :destroy, :id => t.id
      Taxon.find_by_id(t.id).should_not be_blank
    end
    it "should always be possible for admins" do
      u = make_admin
      sign_in u
      t = Taxon.make!
      delete :destroy, :id => t.id
      Taxon.find_by_id(t.id).should be_blank
    end
  end
  
  describe "update" do
    it "should allow curators to supercede locking" do
      user = make_curator
      sign_in user
      locked_parent = Taxon.make!(:locked => true)
      taxon = Taxon.make!
      put :update, :id => taxon.id, :taxon => {:parent_id => locked_parent.id}
      taxon.reload
      taxon.parent_id.should == locked_parent.id
    end
  end
end
