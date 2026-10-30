require "test_helper"

class DeploymentAccessTest < ActionDispatch::IntegrationTest
  setup do
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(file_fixture("test_photo.png")), filename: "document.png", content_type: "image/png"
    )
  end

  teardown do
    @blob.purge
  end

  def sign_in
    post session_path, params: { email_address: users(:owner).email_address, password: "password123" }
  end

  test "originals and variants require a signed-in staff member" do
    variant = @blob.variant(resize_to_limit: [ 80, 80 ])
    [ rails_blob_path(@blob), rails_storage_proxy_path(@blob), rails_representation_path(variant),
      rails_storage_proxy_path(variant) ].each do |path|
      get path
      assert_redirected_to new_session_path
    end
  end

  test "disk URLs stay protected after following an authorized redirect" do
    sign_in
    get rails_blob_path(@blob)
    assert_response :redirect
    disk_url = response.location
    follow_redirect!
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]

    delete session_path
    get disk_url
    assert_redirected_to new_session_path
  end

  test "authenticated proxy downloads cannot be cached publicly" do
    sign_in
    get rails_storage_proxy_path(@blob)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "deactivated users cannot reuse an existing session to read files" do
    sign_in
    users(:owner).update!(active: false)
    get rails_blob_path(@blob)
    assert_redirected_to new_session_path
  end

  test "email password reset is unavailable" do
    get new_session_path
    assert_response :success
    assert_select 'a[href="/passwords/new"]', count: 0
    assert_no_enqueued_jobs do
      post "/passwords", params: { email_address: users(:owner).email_address }
      assert_response :not_found
    end
  end
end
