require "test_helper"

# A bike goes out to someone who may not be in the client base at all, so the
# renter's ID photo is the shop's only hold on it. These cover attaching it at
# handover, adding it late, and who may purge it afterwards.
class RentalDocumentsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @bike = RentalBike.create!(name: "Trek прокат", daily_rate: 300)
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def document(name = "test_photo.png", type = "image/png")
    fixture_file_upload(name, type)
  end

  # shared/modal_form_error is a turbo_stream template — the browser always asks
  # for one, so a test that omits the header hits a MissingTemplate instead of
  # the rejection path it means to exercise.
  def issue!(**extra)
    post rentals_path, params: { rental: { rental_bike_id: @bike.id, renter_name: "Гість",
                                           rented_from: Date.current, rented_to: Date.current + 1 }.merge(extra) },
         headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html, application/xhtml+xml" }
    Rental.order(:id).last
  end

  test "documents attach while the bike is being issued" do
    sign_in_as @owner

    assert_difference -> { Rental.count }, 1 do
      issue!(documents: [ document, document ])
    end

    assert_equal 2, Rental.order(:id).last.documents.count
    assert_redirected_to rentals_path
  end

  test "a non-image is refused and the hire is not created" do
    sign_in_as @owner

    assert_no_difference -> { Rental.count } do
      issue!(documents: [ document("not_an_image.txt", "text/plain") ])
    end

    assert_match "має бути зображенням", response.body
  end

  # The mechanic handing the bike over is the one holding the phone, so adding
  # late must work for every role — a hire issued without documents has to be
  # fixable from the floor.
  test "a mechanic can add documents to an existing hire" do
    sign_in_as @owner
    rental = issue!
    sign_in_as @mechanic

    assert_difference -> { rental.reload.documents.count }, 1 do
      post rental_documents_path(rental), params: { documents: [ document ] }
    end
    assert_redirected_to rentals_path
  end

  test "the rentals list shows a thumbnail per document" do
    sign_in_as @owner
    issue!(documents: [ document ])

    get rentals_path
    assert_select "td[data-label=Документи] img[data-action=?]", "click->lightbox#open", 1
    assert_select "th", text: "Документи"
  end

  # Purging someone's ID is not a call a mechanic makes from the floor —
  # matches how rental bike photos are already gated.
  test "only an admin or owner may delete a document" do
    sign_in_as @owner
    rental = issue!(documents: [ document ])
    target = rental.documents.first

    sign_in_as @mechanic
    assert_no_difference -> { rental.reload.documents.count } do
      delete rental_document_path(rental, target.id)
    end
    assert_redirected_to root_path

    sign_in_as @owner
    assert_difference -> { rental.reload.documents.count }, -1 do
      delete rental_document_path(rental, target.id)
    end
    assert_redirected_to rentals_path
  end

  # A browser cannot repopulate a file input, so a rejected form comes back with
  # an empty picker. The form has to say so instead of losing the files quietly.
  test "a rejected hire warns that the chosen files have to be picked again" do
    sign_in_as @owner
    issue!
    issue!(renter_name: "Другий", documents: [ document ])

    assert_response :unprocessable_entity
    assert_match "вже у прокаті", response.body
    assert_match "Файли не збереглися", response.body
  end

  # --- D67: documents kept on the client ------------------------------------

  test "a client from the base keeps the photos, and the next hire is told they are on file" do
    sign_in_as @owner
    client = clients(:ivan)

    get client_documents_path(client)
    assert_match "документів ще немає", response.body

    rental = issue!(client_id: client.id, renter_name: "", documents: [ document, document ])

    assert_equal 2, client.reload.documents.count
    assert_not rental.documents.attached?, "kept with the person, not this hire"

    get client_documents_path(client)
    assert_select "turbo-frame#rental_client_documents img", 2
    assert_match "фотографувати повторно не треба", response.body

    get rentals_path
    assert_select "td[data-label=Документи] img[data-action=?]", "click->lightbox#open", 2
  end

  test "a photo added from the rentals list for a base client goes to the client" do
    sign_in_as @owner
    rental = issue!(client_id: clients(:ivan).id, renter_name: "")

    post rental_documents_path(rental), params: { documents: [ document ] }

    assert_equal 1, clients(:ivan).documents.count
    assert_not rental.reload.documents.attached?
  end

  # Before D67 a base client's photos were kept on each hire; they still show.
  test "older photos kept on a hire still show on it and on the client page" do
    sign_in_as @owner
    rental = issue!(client_id: clients(:ivan).id, renter_name: "")
    rental.documents.attach(document)

    get rentals_path
    assert_select "td[data-label=Документи] img[data-action=?]", "click->lightbox#open", 1

    get client_path(clients(:ivan))
    assert_select "img[title=?]", "З попередньої видачі в прокат", 1

    get client_documents_path(clients(:ivan))
    assert_match "фотографувати повторно не треба", response.body
  end

  # Two bikes to someone outside the base: one upload, on both hires.
  test "a renter outside the base with two bikes has the photo on both, and removing it from one keeps the other" do
    sign_in_as @owner
    other = RentalBike.create!(name: "Merida прокат", daily_rate: 350)

    issue!(rental_bike_id: nil, rental_bike_ids: [ @bike.id, other.id ], documents: [ document ])
    first, second = Rental.order(:id).last(2)

    assert_equal first.documents.first.blob, second.documents.first.blob, "one upload, shared"
    assert_equal 1, ActiveStorage::Blob.count

    delete rental_document_path(first, first.documents.first.id)

    assert_not first.reload.documents.attached?
    assert second.reload.documents.attached?, "the other hire keeps its photo"
    assert second.documents.first.blob.service.exist?(second.documents.first.blob.key)
  end

  test "on the client page any role adds a document, and only admin or owner removes one" do
    client = clients(:ivan)
    sign_in_as @mechanic

    get client_path(client)
    assert_select "form[action=?]", client_documents_path(client)

    assert_difference -> { client.documents.count }, 1 do
      post client_documents_path(client), params: { documents: [ document ] }, headers: { "HTTP_REFERER" => client_url(client) }
    end
    assert_redirected_to client_url(client)

    target = client.documents.first
    assert_no_difference -> { client.documents.count } do
      delete client_document_path(client, target.id)
    end
    assert_redirected_to root_path

    sign_in_as @owner
    assert_difference -> { client.documents.count }, -1 do
      delete client_document_path(client, target.id)
    end
  end

  test "a non-image is refused on the client page" do
    sign_in_as @owner

    post client_documents_path(clients(:ivan)), params: { documents: [ document("not_an_image.txt", "text/plain") ] }

    assert_equal "Документ має бути зображенням.", flash[:alert]
    assert_equal 0, clients(:ivan).documents.count
  end
end
