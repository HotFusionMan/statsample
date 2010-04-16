require(File.dirname(__FILE__)+'/helpers_tests.rb')
# Reference:
# * http://www.uwsp.edu/psych/Stat/13/anova-2w.htm#III
class StatsampleAnovaTwoWayWithDatasetTestCase < MiniTest::Unit::TestCase
  context(Statsample::Anova::TwoWayWithDataset) do
    setup do
      pa=[5,4,3,4,2,18,19,14,12,15,6,7,5,8,4,6,9,5,9,3].to_scale
      pa.name="Passive Avoidance"
      a=[1,1,1,1,1,2,2,2,2,2,1,1,1,1,1,2,2,2,2,2].to_vector
      a.labels={1=>'0%',2=>'35%'}
      a.name='Diet'
      b=[1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2].to_vector
      b.labels={1=>'Young',2=>'Older'}
      b.name="Age"
      ds={'pa'=>pa,'a'=>a,'b'=>b}.to_dataset
      @anova=Statsample::Anova::TwoWayWithDataset.new(ds,'pa','a','b')
    end
    should "Statsample::Anova.twoway respond to #twoway_with_dataset" do
    assert(Statsample::Anova.respond_to? :twoway_with_dataset)
    end
    should "return correct value for ms_a, ms_b and ms_axb" do
      assert_in_delta(192.2, @anova.ms_a, 0.01)
      assert_in_delta(57.8, @anova.ms_b, 0.01)
      assert_in_delta(168.2, @anova.ms_axb, 0.01)
      
    end
    should "return correct value for f " do
      assert_in_delta(40.68, @anova.f_a, 0.01)
      assert_in_delta(12.23, @anova.f_b, 0.01)
      assert_in_delta(35.60, @anova.f_axb, 0.01)
    end
    should "return correct value for probability for f " do
      assert(@anova.f_a_probability < 0.05)
      assert(@anova.f_b_probability < 0.05)
      assert(@anova.f_axb_probability < 0.05)
    end

    should "respond to summary" do
      @anova.summary_descriptives=true
      @anova.summary_levene=true
      assert(@anova.respond_to? :summary)
      assert(@anova.summary.size>0)
    end
  end
end
