require 'test_helper'

class Admin::ConsultationsControllerTest < ActionController::TestCase
  setup do
    @user = login_as "George"
  end

  test 'is an document controller' do
    assert @controller.is_a?(Admin::DocumentsController), "the controller should have the behaviour of an Admin::DocumentsController"
  end

  test 'new displays consultation form' do
    get :new

    assert_select "form[action='#{admin_consultations_path}']" do
      assert_select "input[name='document[title]'][type='text']"
      assert_select "textarea[name='document[body]']"
      assert_select "input[name='document[attach_file]'][type='file']"
      assert_select "select[name*='document[opening_on']", count: 3
      assert_select "select[name*='document[closing_on']", count: 3
      assert_select "select[name*='document[organisation_ids]']"
      assert_select "select[name*='document[ministerial_role_ids]']"
      assert_select "input[name*='document[nation_inapplicabilities_attributes]'][type='checkbox']", count: 4
      assert_select "input[type='submit']"
    end
  end

  test 'creating creates a new consultation' do
    first_org = create(:organisation)
    second_org = create(:organisation)
    first_minister = create(:ministerial_role)
    second_minister = create(:ministerial_role)
    attributes = attributes_for(:consultation)

    post :create, document: attributes.merge(
      organisation_ids: [first_org.id, second_org.id],
      ministerial_role_ids: [first_minister.id, second_minister.id],
      nation_inapplicabilities_attributes: {"0" => {_destroy: true, nation_id: Nation.england}, "1" => {_destroy: true, nation_id: Nation.scotland}, "2" => {_destroy: false, nation_id: Nation.wales}, "3" => {_destroy: false, nation_id: Nation.northern_ireland}}
    )

    created_consultation = Consultation.last
    assert_equal attributes[:title], created_consultation.title
    assert_equal attributes[:body], created_consultation.body
    assert_equal attributes[:opening_on].to_date, created_consultation.opening_on
    assert_equal attributes[:closing_on].to_date, created_consultation.closing_on
    assert_equal [first_org, second_org], created_consultation.organisations
    assert_equal [first_minister, second_minister], created_consultation.ministerial_roles
    assert_equal [Nation.wales, Nation.northern_ireland], created_consultation.inapplicable_nations
  end

  test 'creating takes the writer to the consultation page' do
    post :create, document: attributes_for(:consultation)

    assert_redirected_to admin_consultation_path(Consultation.last)
    assert_equal 'The document has been saved', flash[:notice]
  end

  test 'show displays consultation opening date' do
    consultation = create(:consultation, opening_on: Date.new(2011, 10, 10))
    get :show, id: consultation
    assert_select '.opening_on', text: 'Opened on October 10th, 2011'
  end

  test 'show displays consultation closing date' do
    consultation = create(:consultation, opening_on: Date.new(2010, 01, 01), closing_on: Date.new(2011, 01, 01))
    get :show, id: consultation
    assert_select '.closing_on', text: 'Closed on January 1st, 2011'
  end

  test 'show displays consultation attachment' do
    consultation = create(:consultation, attachment: create(:attachment))
    get :show, id: consultation
    assert_select '.attachment a', text: consultation.attachment.filename
  end

  test 'show displays inapplicable nations' do
    published_policy = create(:consultation)
    published_policy.inapplicable_nations << Nation.wales

    get :show, id: published_policy

    assert_select_object Nation.wales
  end

  test 'show displays related policies' do
    policy = create(:policy)
    consultation = create(:consultation, documents_related_to: [policy])
    get :show, id: consultation
    assert_select_object policy
  end

  test 'edit displays consultation form' do
    consultation = create(:consultation, inapplicable_nations: [Nation.northern_ireland])

    get :edit, id: consultation

    assert_select "form[action='#{admin_consultation_path(consultation)}']" do
      assert_select "input[name='document[title]'][type='text']"
      assert_select "textarea[name='document[body]']"
      assert_select "input[name='document[attach_file]'][type='file']"
      assert_select "select[name*='document[opening_on']", count: 3
      assert_select "select[name*='document[closing_on']", count: 3
      assert_select "select[name*='document[organisation_ids]']"
      assert_select "select[name*='document[ministerial_role_ids]']"
      assert_select "input[name*='document[nation_inapplicabilities_attributes]'][type='checkbox']", count: 4
      assert_select "input[name*='document[nation_inapplicabilities_attributes]'][type='checkbox'][checked='checked']", count: 1
      assert_select "input[type='submit']"
    end
  end

  test 'update updates consultation' do
    first_org = create(:organisation)
    second_org = create(:organisation)
    first_minister = create(:ministerial_role)
    second_minister = create(:ministerial_role)

    consultation = create(:consultation, organisations: [first_org], ministerial_roles: [first_minister])
    northern_ireland_inapplicability = consultation.nation_inapplicabilities.create!(nation: Nation.northern_ireland)

    put :update, id: consultation, document: {
      title: "new-title",
      body: "new-body",
      opening_on: 1.day.ago,
      closing_on: 50.days.from_now,
      organisation_ids: [second_org.id],
      ministerial_role_ids: [second_minister.id],
      nation_inapplicabilities_attributes: {"0" => {_destroy: true, nation_id: Nation.england}, "1" => {_destroy: false, nation_id: Nation.scotland}, "2" => {_destroy: true, nation_id: Nation.wales}, "3" => {id: northern_ireland_inapplicability, _destroy: true, nation_id: northern_ireland_inapplicability.nation_id}}
    }

    consultation.reload
    assert_equal "new-title", consultation.title
    assert_equal "new-body", consultation.body
    assert_equal 1.day.ago.to_date, consultation.opening_on
    assert_equal 50.days.from_now.to_date, consultation.closing_on
    assert_equal [second_org], consultation.organisations
    assert_equal [second_minister], consultation.ministerial_roles
    assert_equal [Nation.scotland], consultation.inapplicable_nations
  end
end