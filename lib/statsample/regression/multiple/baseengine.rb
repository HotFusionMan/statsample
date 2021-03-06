module Statsample
  module Regression
    module Multiple
      # Base class for Multiple Regression Engines
      class BaseEngine
        include Statsample::Summarizable
        # Name of analysis
        attr_accessor :name
        # Minimum number of  valid case for pairs of correlation
        attr_reader :cases
        # Number of valid cases (listwise)
        attr_reader :valid_cases
        # Number of total cases (dataset.cases)
        attr_reader :total_cases
        def self.univariate?
          true
        end
        def initialize(ds, y_var, opts = Hash.new)
          @ds=ds
          @predictors_n=@ds.fields.size-1
          @total_cases=@ds.cases
          @cases=@ds.cases
          @y_var=y_var
          @r2=nil
          @name=_("Multiple Regression:  %s over %s") % [ ds.fields.join(",") , @y_var]
          opts.each{|k,v|
            self.send("#{k}=",v) if self.respond_to? k
          }
        end
        # Calculate F Test
        def anova
          @anova||=Statsample::Anova::OneWay.new(:ss_num=>ssr, :ss_den=>sse, :df_num=>df_r, :df_den=>df_e, :name_numerator=>_("Regression"), :name_denominator=>_("Error"), :name=>"ANOVA")
        end
        # Standard error of estimate
        def se_estimate
          Math::sqrt(sse.quo(df_e))
        end
        # Retrieves a vector with predicted values for y
        def predicted
          @total_cases.times.collect { |i|
            invalid=false
            vect=@dep_columns.collect {|v| invalid=true if v[i].nil?; v[i]}
            if invalid
              nil
            else
              process(vect)
            end
          }.to_vector(:scale)
        end
        # Retrieves a vector with standarized values for y
        def standarized_predicted
          predicted.standarized
        end
        # Retrieves a vector with residuals values for y
        def residuals
          (0...@total_cases).collect{|i|
            invalid=false
            vect=@dep_columns.collect{|v| invalid=true if v[i].nil?; v[i]}
            if invalid or @ds[@y_var][i].nil?
              nil
            else
              @ds[@y_var][i] - process(vect)
            end
          }.to_vector(:scale)
        end
        # R Multiple
        def r
          raise "You should implement this"
        end
        # Sum of squares Total
        def sst
          raise "You should implement this"
        end
        def r2_adjusted
          r2-((1-r2)*@predictors_n).quo(df_e)
        end
        # Sum of squares (regression)
        def ssr
          r2*sst
        end
        # Sum of squares (Error)
        def sse
          sst - ssr
        end
        # T values for coeffs
        def coeffs_t
          out={}
          se=coeffs_se
          coeffs.each do |k,v|
            out[k]=v / se[k]
          end
          out
        end
        # Mean square Regression
        def msr
          ssr.quo(df_r)
        end
        # Mean Square Error
        def mse
          sse.quo(df_e)
        end
        # Degrees of freedom for regression
        def df_r
          @predictors_n
        end
        # Degrees of freedom for error
        def df_e
          @valid_cases-@predictors_n-1
        end
        # Fisher for Anova
        def f
          anova.f
        end
        # p-value of Fisher
        def probability
          anova.probability
        end
        # Tolerance for a given variable
        # http://talkstats.com/showthread.php?t=5056
        def tolerance(var)
          ds=assign_names(@dep_columns)
          ds.each{|k,v|
          ds[k]=v.to_vector(:scale)
          }
          lr=self.class.new(ds.to_dataset,var)
          1-lr.r2
        end
        # Tolerances for each coefficient
        def coeffs_tolerances
          @fields.inject({}) {|a,f|
          a[f]=tolerance(f);
            a
          }
        end
        # Standard Error for coefficients
        def coeffs_se
          out={}
          mse=sse.quo(df_e)
          coeffs.each {|k,v|
            out[k]=Math::sqrt(mse/(@ds[k].sum_of_squares * tolerance(k)))
          }
          out
        end
        # Estandar error of R^2
        # ????
        def se_r2
          Math::sqrt((4*r2*(1-r2)**2*(df_e)**2).quo((@cases**2-1)*(@cases+3)))
        end
         
        # Estimated Variance-Covariance Matrix
        # Used for calculation of se of constant
        def estimated_variance_covariance_matrix
          mse_p=mse
          columns=[]
          @ds_valid.fields.each{|k|
            v=@ds_valid[k]
            columns.push(v.data) unless k==@y_var
          }
          columns.unshift([1.0]*@valid_cases)
          x=Matrix.columns(columns)
          matrix=((x.t*x)).inverse * mse
          matrix.collect {|i| Math::sqrt(i) if i>0 }
        end
        # T for constant
        def constant_t
          constant.to_f/constant_se
        end
        # Standard error for constant
        def constant_se
          estimated_variance_covariance_matrix[0,0]
        end
        def report_building(b)
          b.section(:name=>@name) do |g|
            c=coeffs
            g.text _("Engine: %s") % self.class
            g.text(_("Cases(listwise)=%d(%d)") % [@total_cases, @valid_cases])
            g.text _("R=%0.3f") % r
            g.text _("R^2=%0.3f") % r2
            g.text _"R^2 Adj=%0.3f" % r2_adjusted
            g.text _("Std.Error R=%0.3f") % se_estimate
            
            g.text(_("Equation")+"="+ sprintf('%0.3f',constant) +" + "+ @fields.collect {|k| sprintf('%0.3f%s',c[k],k)}.join(' + ') )
            
            g.parse_element(anova)
            sc=standarized_coeffs
            cse=coeffs_se
            g.table(:name=>_("Beta coefficients"), :header=>%w{coeff b beta se t}.collect{|field| _(field)} ) do |t|
				t.row([_("Constant"), sprintf("%0.3f", constant), "-", constant_se.nil? ? "": sprintf("%0.3f", constant_se), constant_t.nil? ? "" : sprintf("%0.3f", constant_t)])
              @fields.each do |f|
                t.row([f, sprintf("%0.3f", c[f]), sprintf("%0.3f", sc[f]), sprintf("%0.3f", cse[f]), sprintf("%0.3f", c[f].quo(cse[f]))])
              end  
            end
          end
        end
        
        
        def assign_names(c)
          a={}
          @fields.each_index {|i|
            a[@fields[i]]=c[i]
          }
          a
        end

        # Sum of squares of regression
        # using the predicted value minus y mean
        def ssr_direct
          mean=@dy.mean
          cases=0
          ssr=(0...@ds.cases).inject(0) {|a,i|
            invalid=false
            v=@dep_columns.collect{|c| invalid=true if c[i].nil?; c[i]}
            if !invalid
              cases+=1
              a+((process(v)-mean)**2)
            else
              a
            end
          }
          ssr
        end
        def sse_direct
          sst-ssr
        end
        def process(v)
          c=coeffs
          total=constant
          @fields.each_index{|i|
            total+=c[@fields[i]]*v[i]
          }
          total
        end
      end
    end
  end
end