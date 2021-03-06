require(File.dirname(__FILE__)+'/helpers_tests.rb')

class StatsampleFactorTestCase < MiniTest::Unit::TestCase
  include Statsample::Fixtures
  def test_antiimage
    cor=Matrix[[1,0.964, 0.312],[0.964,1,0.411],[0.312,0.411,1]]
    expected=Matrix[[0.062,-0.057, 0.074],[-0.057, 0.057, -0.089], [0.074, -0.089, 0.729]]
    ai=Statsample::Factor.anti_image_covariance_matrix(cor)
    assert(Matrix.equal_in_delta?(expected, ai, 0.01), "#{expected.to_s} not equal to #{ai.to_s}")
  end
  def test_kmo
      @v1=[1 ,2 ,3 ,4 ,7 ,8 ,9 ,10,14,15,20,50,60,70].to_scale
      @v2=[5 ,6 ,11,12,13,16,17,18,19,20,30,0,0,0].to_scale
      @v3=[10,3 ,20,30,40,50,80,10,20,30,40,2,3,4].to_scale
      # KMO: 0.490
      ds={'v1'=>@v1,'v2'=>@v2,'v3'=>@v3}.to_dataset
      cor=Statsample::Bivariate.correlation_matrix(ds)
     kmo=Statsample::Factor.kmo(cor)
     assert_in_delta(0.667, kmo,0.001)
     assert_in_delta(0.81, Statsample::Factor.kmo(harman_817),0.01)
     
  end
  def test_kmo_univariate
    m=harman_817
    expected=[0.73,0.76,0.84,0.87,0.53,0.93,0.78,0.86]
    m.row_size.times.map {|i|
      assert_in_delta(expected[i], Statsample::Factor.kmo_univariate(m,i),0.01)
    }
  end
  def test_parallelanalysis_with_data
    samples=100
    variables=10
    iterations=50
    rng = GSL::Rng.alloc()
    f1=samples.times.collect {rng.ugaussian()}.to_scale
    f2=samples.times.collect {rng.ugaussian()}.to_scale    
    vectors={}
    variables.times do |i|
      if i<5
        vectors["v#{i}"]=samples.times.collect {|nv|
          f1[nv]*5+f2[nv]*2+rng.ugaussian()
        }.to_scale
      else
        vectors["v#{i}"]=samples.times.collect {|nv|
          f2[nv]*5+f1[nv]*2+rng.ugaussian()
        }.to_scale
      end
      
    end
    ds=vectors.to_dataset
    
    pa1=Statsample::Factor::ParallelAnalysis.new(ds, :bootstrap_method=>:data, :iterations=>iterations)
    pa2=Statsample::Factor::ParallelAnalysis.with_random_data(samples,variables,:iterations=>iterations,:percentil=>95)
    3.times do |n|
      var="ev_0000#{n+1}"
      assert_in_delta(pa1.ds_eigenvalues[var].mean,pa2.ds_eigenvalues[var].mean,0.04)
    end
  end
  def test_parallelanalysis
    pa=Statsample::Factor::ParallelAnalysis.with_random_data(305,8,:iterations=>100,:percentil=>95)
    assert_in_delta(1.2454, pa.ds_eigenvalues['ev_00001'].mean, 0.01)
    assert_in_delta(1.1542, pa.ds_eigenvalues['ev_00002'].mean, 0.01)
    assert_in_delta(1.0836, pa.ds_eigenvalues['ev_00003'].mean, 0.01)
    #puts pa.summary
    assert(pa.summary.size>0)
    #pa=Statsample::Factor::ParallelAnalysis.with_random_data(305,8,100, 95, true)
    #puts pa.summary
  end
  def test_map
    fields=%w{height arm.span forearm lower.leg weight bitro.diameter chest.girth chest.width}
    m=Matrix[ 
          [ 1, 0.846, 0.805, 0.859, 0.473, 0.398, 0.301, 0.382],
          [ 0.846, 1, 0.881, 0.826, 0.376, 0.326, 0.277, 0.415],
          [ 0.805, 0.881, 1, 0.801, 0.38, 0.319, 0.237, 0.345],
          [ 0.859, 0.826, 0.801, 1, 0.436, 0.329, 0.327, 0.365],
          [ 0.473, 0.376, 0.38, 0.436, 1, 0.762, 0.73, 0.629],
          [ 0.398, 0.326, 0.319, 0.329, 0.762, 1, 0.583, 0.577],
          [ 0.301, 0.277, 0.237, 0.327, 0.73, 0.583, 1, 0.539],
          [ 0.382, 0.415, 0.345, 0.365, 0.629, 0.577, 0.539, 1]
    ]
    map=Statsample::Factor::MAP.new(m)
    assert_in_delta(map.minfm, 0.066445,0.00001)
    assert_equal(map.number_of_factors, 2)
    assert_in_delta(map.fm[0], 0.312475,0.00001)
    assert_in_delta(map.fm[1], 0.245121,0.00001)

  end
  # Tested with SPSS and R
  def test_pca
      a=[2.5, 0.5, 2.2, 1.9, 3.1, 2.3, 2.0, 1.0, 1.5, 1.1].to_scale
      b=[2.4, 0.7, 2.9, 2.2, 3.0, 2.7, 1.6, 1.1, 1.6, 0.9].to_scale
      a.recode! {|c| c-a.mean}
      b.recode! {|c| c-b.mean}
      ds={'a'=>a,'b'=>b}.to_dataset
      cov_matrix=Statsample::Bivariate.covariance_matrix(ds)
      if Statsample.has_gsl?
        pca=Statsample::Factor::PCA.new(cov_matrix,:use_gsl=>true)
        pca_set(pca)
      else
        skip("Eigenvalues could be calculated with GSL (requires gsl)")
      end
      pca=Statsample::Factor::PCA.new(cov_matrix,:use_gsl=>false)
      pca_set(pca)
  end
  def pca_set(pca)
      expected_eigenvalues=[1.284, 0.0490]
      expected_eigenvalues.each_with_index{|ev,i|
        assert_in_delta(ev,pca.eigenvalues[i],0.001)
      }
      expected_communality=[0.590, 0.694]
      expected_communality.each_with_index{|ev,i|
        assert_in_delta(ev,pca.communalities[i],0.001)
      }
      expected_cm=[0.768, 0.833]
      obs=pca.component_matrix(1).column(0).to_a
      expected_cm.each_with_index{|ev,i|
        assert_in_delta(ev,obs[i],0.001)
      }

      expected_fm_1=::Matrix[[0.677], [0.735]]
      expected_fm_2=::Matrix[[0.677,0.735], [0.735, -0.677]]
      _test_matrix(expected_fm_1,pca.feature_vector(1))
      _test_matrix(expected_fm_2,pca.feature_vector(2))
      assert(pca.summary)
  end

  # Tested with R
  def test_principalaxis
      matrix=::Matrix[
      [1.0, 0.709501601093587, 0.877596585880047, 0.272219316266807],  [0.709501601093587, 1.0, 0.291633797330304, 0.871141831433844], [0.877596585880047, 0.291633797330304, 1.0, -0.213373722977167], [0.272219316266807, 0.871141831433844, -0.213373722977167, 1.0]]
      
      
      fa=Statsample::Factor::PrincipalAxis.new(matrix,:m=>1, :max_iterations=>50)

      cm=::Matrix[[0.923],[0.912],[0.507],[0.483]]
      
      _test_matrix(cm,fa.component_matrix)
      
      h2=[0.852,0.832,0.257,0.233]
      h2.each_with_index{|ev,i|
        assert_in_delta(ev,fa.communalities[i],0.001)
      }
      eigen1=2.175
      assert_in_delta(eigen1, fa.eigenvalues[0],0.001)
      assert(fa.summary.size>0)
      fa=Statsample::Factor::PrincipalAxis.new(matrix,:smc=>false)
            
      assert_raise RuntimeError do
        fa.iterate
      end

  end


  def test_rotation_varimax
    a = Matrix[ [ 0.4320,  0.8129,  0.3872]  ,
      [0.7950, -0.5416,  0.2565]  ,
      [0.5944,  0.7234, -0.3441],
    [0.8945, -0.3921, -0.1863] ]

    expected= Matrix[[-0.0204423,     0.938674,    -0.340334],
      [0.983662, 0.0730206, 0.134997],
      [0.0826106, 0.435975, -0.893379],
    [0.939901, -0.0965213, -0.309596]]
    varimax=Statsample::Factor::Varimax.new(a)
    assert(!varimax.rotated.nil?, "Rotated shouldn't be empty")
    assert(!varimax.component_transformation_matrix.nil?, "Component matrix shouldn't be empty")
    assert(!varimax.h2.nil?, "H2 shouldn't be empty")
    
    _test_matrix(expected,varimax.rotated)
    assert(varimax.summary.size>0)
  end
  def _test_matrix(a,b)
    a.row_size.times {|i|
      a.column_size.times {|j|
        assert_in_delta(a[i,j], b[i,j],0.001)
      }
    }
  end
end
