require "test_helper"

class LandlockTest < ActiveSupport::TestCase
  context "Landlock.restrict!" do
    # This raises before the process is restricted, so it's safe to run in the test process.
    should "not allow paths that are symlinks" do
      Dir.mktmpdir do |dir|
        File.symlink(Rails.root.join("Gemfile"), "#{dir}/link")
        error = assert_raises(Landlock::Error) { Landlock.restrict!(read: ["#{dir}/link"]) }

        assert_equal("#{dir}/link can't be sandboxed because it's a symlink", error.message)
      end
    end
  end
end
