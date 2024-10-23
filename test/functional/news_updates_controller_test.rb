require "test_helper"

class NewsUpdatesControllerTest < ActionDispatch::IntegrationTest
  context "the news updates controller" do
    setup do
      @admin = create(:admin_user)
      as(@admin) do
        @news_update = create(:news_update, creator: @admin, message: "test news")
      end
    end

    context "index action" do
      should "render" do
        get_auth news_updates_path, @admin
        assert_response :success
      end
    end

    context "new action" do
      should "render" do
        get_auth new_news_update_path, @admin
        assert_response :success
      end
    end

    context "edit action" do
      should "render" do
        get_auth edit_news_update_path(@news_update), @admin
        assert_response :success
      end
    end

    context "update action" do
      should "work" do
        put_auth news_update_path(@news_update), @admin, params: {:news_update => {:message => "zzz"}}
        assert_redirected_to(news_updates_path)

        get_auth posts_path, @admin
        assert_select "#news-updates > div > div", count: 1, text: "zzz"
      end
    end

    context "create action" do
      should "work" do
        assert_difference("NewsUpdate.active.count") do
          post_auth news_updates_path, @admin, params: {:news_update => {:message => "zzz"}}
        end
        assert_redirected_to(news_updates_path)

        get_auth posts_path, @admin
        assert_select "#news-updates > div > div", count: 2
        assert_select "#news-updates > div > div", count: 1, text: @news_update.message
        assert_select "#news-updates > div > div", count: 1, text: "zzz"
      end
    end

    context "delete action" do
      should "work" do
        assert_difference("NewsUpdate.active.count", -1) do
          delete_auth news_update_path(@news_update), @admin
        end
        assert_redirected_to(news_updates_path)
        get_auth posts_path, @admin
        assert_select "#news-updates > div > div", count: 0
      end
    end

    context "undelete action" do
      should "work" do
        put_auth news_update_path(@news_update), @admin, params: {:news_update => {:is_deleted => false}}
        assert_redirected_to(news_updates_path)

        get_auth posts_path, @admin
        assert_select "#news-updates > div > div", count: 1, text: @news_update.message
      end
    end
  end
end
