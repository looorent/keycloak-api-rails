require "rbconfig"

RSpec.describe "The library without ActiveSupport" do

  let(:probe) { File.expand_path("../../support/activesupport_free_probe.rb", __FILE__) }

  # RUBYOPT is cleared so that nothing set up by bundler is preloaded in the probe process.
  def run_probe
    output = IO.popen({ "RUBYOPT" => nil }, [RbConfig.ruby, probe], err: [:child, :out], &:read)
    [$?.exitstatus, output]
  end

  it "loads and behaves the same way when ActiveSupport is not available" do
    status, output = run_probe

    expect(status).to eq(0), "The library relies on ActiveSupport:\n#{output}"
  end
end
