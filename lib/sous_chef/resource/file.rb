module SousChef
  module Resource
    class File < Directory
      attr_reader :name

      def initialize(context, name, &block)
        super
      end

      def content(content=nil)
        if content.nil?
          @content
        else
          @content = content
        end
      end

      def to_script
        @script ||= begin
          instance_eval(&block)
          %{
if ! test -e "#{path}"; then
  #{file_creation_command}
fi
#{mode_command}
          }.strip
        end
      end

      protected
        def escaped_content
          # many slashes because single-quote has some sort of
          # special meaning in regexp replacement strings
          content && content.gsub(/'/, %q{\\\\'})
        end

        def file_creation_command
          if content
            %{echo '#{escaped_content}' > "#{path}"}
          else
            %{touch "#{path}"}
          end
        end

        def mode_command
          if mode
            sprintf(%{chmod %04o "%s"}, mode, path)
          end
        end
    end
  end
end
