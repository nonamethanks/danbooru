# frozen_string_literal: true

require_relative "test_helper"

describe Danbooru::Tempfile do
  it "deletes the tempfile when it is garbage collected" do
    tempfile = Danbooru::Tempfile.new("test")
    path = tempfile.path
    expect(File.exist?(path)).must_equal(true)

    tempfile = nil
    GC.start
    GC.start

    expect(File.exist?(path)).must_equal(false)
  end
end
