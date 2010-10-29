module Sinatra
  module BeforeOnlyFilter
    def before_only(routes, &block)
      before do
        routes.map! { |r|
          r = r.gsub(/\*/, '\w+')
          r.rsub(/\//, '\/')
        }
        if routes.any? { |r|
            !(request.path =~ /^#{r}$/).nil?
          }
          instance_eval(&block)
        end
      end
    end

    def before_only_re(re, &block)
      before do
        m = /^#{re}$/.match(request.path)
        unless m.nil?
          m = m.to_a
          m.shift
          params[:capture] = m
          instance_eval(&block)
        end
      end
    end
  end

  register BeforeOnlyFilter
end
