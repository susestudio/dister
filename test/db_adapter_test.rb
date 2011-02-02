require File.expand_path('../test_helper', __FILE__)

class DbAdapterTest < Test::Unit::TestCase

  GOOD_CONFIG = File.expand_path('../fixtures/supported_database.yml', __FILE__)
  BAD_CONFIG  = File.expand_path('../fixtures/unsupported_database.yml', __FILE__)


  context "Initialization" do
    should "raise an exception if the adapter doesn't exist" do
      assert_raises RuntimeError do
        adapter = Dister::DbAdapter.new BAD_CONFIG
      end
    end

    should "not raise an exception if the adapter exists" do
      assert_nothing_raised do
        adapter = Dister::DbAdapter.new GOOD_CONFIG
      end
    end
  end

  context "dump handling" do
    should "tell you there's no dump" do
        adapter = Dister::DbAdapter.new GOOD_CONFIG
        assert !adapter.has_dump?

        # there's no foo.sql file
        adapter = Dister::DbAdapter.new GOOD_CONFIG, "foo.sql"
        assert !adapter.has_dump?
    end
    
    should "tell you there's a dump" do
      begin
        FileUtils.touch "foo.sql"
        adapter = Dister::DbAdapter.new GOOD_CONFIG, "foo.sql"
        assert adapter.has_dump?
      ensure
        FileUtils.rm_rf "foo.sql"
      end
    end
  end

  context "mysql adapter" do
    setup do
      @user = "foo"
      @password = "secret"
      @db_name = "cool_rails_app"
      @adapter = "mysql"
      @dump    = "cool_rails_app.sql"
      @db_adapter = Dister::DbAdapter.new GOOD_CONFIG, @dump
    end

    should "return package name" do
      required_packages = @db_adapter.packages
      assert required_packages.include?("mysql-community-server")
      assert required_packages.include?("ruby-mysql")
    end

    should "return daemon name" do
      assert_equal "mysql", @db_adapter.daemon_name
    end

    should "return create user command" do
      assert_nothing_raised do
        cmd = @db_adapter.create_user_cmd
        assert cmd.include? @user
        assert cmd.include? @password
      end
    end

    should "restore dump" do
      assert_nothing_raised do
        cmd = @db_adapter.restore_dump_cmd
        assert cmd.include? @user
        assert cmd.include? @password
        assert cmd.include? @db_name
        assert cmd.include? @dump
      end
    end
  end
end
