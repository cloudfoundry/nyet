require 'spec_helper'
require 'net/http'
require 'support/test_app'

describe 'Managing ElephantSQL' do
  let(:user) { RegularUser.from_env }
  let(:app_name) { 'elephantsql' }
  let!(:org) { user.find_organization_by_name(ENV.fetch("NYET_ORGANIZATION_NAME")) }
  let!(:space) { user.create_space(org) }

  after do
    monitoring.record_action(:delete) do
      space.delete!(:recursive => true)
    end
  end

  it 'allows users to create, bind, read, write, unbind, and delete the ElephantSQL service' do
    plan = user.find_service_plan('elephantsql-dev', 'turtle')
    plan.should be

    service_instance = nil
    monitoring.record_action(:create) do
      service_instance = user.create_service_instance(space, 'elephantsql-dev', 'turtle')
    end
    service_instance.guid.should be

    app = user.create_app(space, app_name)
    binding = user.bind_service_to_app(service_instance, app)
    binding.guid.should be

    route = user.create_route(app, "#{app_name}-#{SecureRandom.hex(2)}")
    app.upload(File.expand_path("../../apps/ruby/app_sinatra_service", __FILE__))
    monitoring.record_action(:start) do
      app.start!(true)
    end

    test_app = TestApp.new(app, route.name, service_instance, 'pg')
    test_app.when_running do
      test_app.insert_value('key', 'value').should be_a Net::HTTPSuccess
      test_app.get_value('key').should == 'value'
    end

    binding.delete!
    service_instance.delete!
    app.delete!
  end
end