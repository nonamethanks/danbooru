# frozen_string_literal: true

require_relative "test_helper"

describe Danbooru::Tempdir do
  it "deletes the tempdir when the block is exited" do
    path = nil

    Danbooru::Tempdir.create(["danbooru-", ".zip"]) do |tempdir|
      path = tempdir.path
      expect(File.exist?(path)).must_equal(true)
    end

    expect(File.exist?(path)).must_equal(false)
  end

  it "deletes the tempdir when it is garbage collected" do
    tempdir = Danbooru::Tempdir.create(["danbooru-", ".zip"])
    path = tempdir.path
    expect(File.exist?(path)).must_equal(true)

    tempdir = nil
    GC.start
    GC.start

    expect(File.exist?(path)).must_equal(false)
  end
end
