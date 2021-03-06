require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe SousChef do
  describe "execute" do
    it "returns a simple command" do
      script = SousChef.prep do
        execute "run a command" do
          command "ls"
        end
      end
      script.should == "ls\n"
    end

    it "concatenates multiple commands" do
      script = SousChef.prep do
        execute "run multiple commands" do
          command "curl -O http://www.example.com/file.tgz"
          command "tar xvfz file.tgz"
        end
      end
      script.should == "curl -O http://www.example.com/file.tgz\ntar xvfz file.tgz\n"
    end

    it "respects multiline commands" do
      script = SousChef.prep do
        execute "run multiline commands" do
          command <<-CODE
curl -O http://www.example.com/file.tgz
tar xvfz file.tgz
          CODE
        end
      end
      script.should == "curl -O http://www.example.com/file.tgz\ntar xvfz file.tgz\n"
    end

    it "changes current working directory on cwd" do
      script = SousChef.prep do
        execute "change directory" do
          cwd "/home/user"
        end
      end
      script.should == "cd /home/user\n"
    end

    it "changes the current working directory before any commands" do
      script = SousChef.prep do
        execute "change directory before commands" do
          command "cp foo bar"
          cwd "/home/user"
        end
      end
      script.should == "cd /home/user\ncp foo bar\n"
    end

    it "can use a method defined within the prep block" do
      script = SousChef.prep do
        def report(message)
          command "echo #{message}"
        end

        execute "say the date" do
          report "`date`"
        end
      end
      script.should == "echo `date`\n"
    end

    it "scopes cwd to the correct execute block" do
      script = SousChef.prep do
        execute "install bundler" do
          command "gem install bundler"
        end

        execute "bundle some project" do
          cwd "/data/projects/foo"
          command "gem bundle"
        end
      end
      script.should == "gem install bundler\n\ncd /data/projects/foo\ngem bundle\n"
    end

    it "wraps commands in an if block on not_if" do
      script = SousChef.prep do
        execute "bundle some project" do
          cwd "/data/projects/foo"
          command "gem bundle"
          not_if "test -d /data/projects/foo/vendor"
        end
      end
      script.should == <<-EOSH
if ! test -d /data/projects/foo/vendor; then
  cd /data/projects/foo
  gem bundle
fi
      EOSH
    end

    it "wraps commands in an if block with test -e on creates" do
      script = SousChef.prep do
        execute "bundle some project" do
          creates "/data/projects/foo/vendor"
          cwd "/data/projects/foo"
          command "gem bundle"
        end
      end
      script.should == <<-EOSH
if ! test -e /data/projects/foo/vendor; then
  cd /data/projects/foo
  gem bundle
fi
      EOSH
    end
  end

  describe "file" do
    it "creates a file" do
      script = SousChef.prep do
        file "bash config" do
          path "~/.bash_profile"
          content "export PATH=~/bin:$PATH"
        end
      end
      script.should == <<-EOSH
if ! test -e ~/.bash_profile; then
  cat <<'SousChefHeredoc' > ~/.bash_profile
export PATH=~/bin:\$PATH
SousChefHeredoc
fi
      EOSH
    end
  end

  describe "directory" do
    it "creates a directory" do
      script = SousChef.prep do
        directory "/usr/local/bin"
      end
      script.should == "mkdir -p /usr/local/bin\n"
    end
  end

  describe "log" do
    it "sets logging to a file" do
      script = SousChef.prep do
        log "~/script.log"
      end
      script.should == "exec 1>~/script.log 2>&1\n"
    end

    it "allows logging stdout only" do
      script = SousChef.prep do
        log do
          stdout "stdout.log"
        end
      end
      script.should == "exec 1>stdout.log\n"
    end

    it "allows logging stdout and stderr" do
      script = SousChef.prep do
        log do
          stdout "stdout.log"
          stderr "stderr.log"
        end
      end
      script.should == "exec 1>stdout.log 2>stderr.log\n"
    end
  end

  describe "halt_on_failed_command" do
    it "outputs set -e" do
      script = SousChef.prep do
        halt_on_failed_command
      end
      script.should == "set -e\n"
    end
  end

  describe "echo" do
    it "echoes the given string" do
      script = SousChef.prep do
        echo "I'm in bash!"
      end
      script.should == %{echo 'I'"'"'m in bash!'\n}
    end

    it "echoes from anywhere" do
      script = SousChef.prep do
        file "newfile.txt" do
          echo "I'm in bash!"
          content "something"
        end
      end
      script.should == <<-EOSH
if ! test -e newfile.txt; then
  echo 'I'"'"'m in bash!'
  cat <<'SousChefHeredoc' > newfile.txt
something
SousChefHeredoc
fi
      EOSH
    end
  end

  describe "gemfile" do
    it "creates a gemfile with the given path" do
      script = SousChef.prep do
        gemfile "/data/projects/foo" do
          gem "rails", "2.3.2"
          gem "rack",  "1.0.0"
        end
      end
      script.should == <<-EOSH
if ! test -e /data/projects/foo/Gemfile; then
  cat <<'SousChefHeredoc' > /data/projects/foo/Gemfile
gem "rack",  "1.0.0"
gem "rails", "2.3.2"
SousChefHeredoc
fi
      EOSH
    end

    it "can have sources" do
      script = SousChef.prep do
        gemfile "/data/projects/foo" do
          gem "rails"
          source 'http://gems.engineyard.com/'
        end
      end
      script.should == <<-EOSH
if ! test -e /data/projects/foo/Gemfile; then
  cat <<'SousChefHeredoc' > /data/projects/foo/Gemfile
source "http://gems.engineyard.com/"

gem "rails"
SousChefHeredoc
fi
      EOSH
    end
  end

  describe "node" do
    it "has a node accessible as set within the recipe" do
      recipe = SousChef::Recipe.new do
        execute "run a command" do
          command "ls #{node[:dir]}"
        end
      end
      recipe.node = { :dir => '/home' }
      recipe.to_script.should == "ls /home\n"
    end
  end
end
