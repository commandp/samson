require_relative '../test_helper'

describe JobsController do
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }
  let(:deployer) { users(:deployer) }
  let(:command) { "echo hello" }
  let(:job) { Job.create!(command: command, project: project, user: deployer) }
  let(:job_service) { stub(execute!: nil) }
  let(:execute_called) { [] }

  setup do
    JobService.stubs(:new).with(project, deployer).returns(job_service)
    job_service.stubs(:execute!).capture(execute_called).returns(job)
  end

  as_a_viewer do
    describe "a GET to :index" do
      setup { get :index, project_id: project.to_param }

      it "renders the template" do
        assert_template :index
      end
    end

    describe "a GET to :show" do
      describe 'with a job' do
        setup { get :show, project_id: project.to_param, id: job }

        it "renders the template" do
          assert_template :show
        end
      end

      describe "with no job" do
        setup { get :show, project_id: project.to_param, id: "job:nope" }

        it "redirects to the root page" do
          assert_redirected_to root_path
        end

        it "sets the flash error" do
          request.flash[:error].wont_be_nil
        end
      end

      describe "with format .text" do
        setup { get :show, format: :text, project_id: project.to_param, id: job }

        it "responds with a plain text file" do
          assert_equal response.content_type, "text/plain"
        end

        it "responds with a .log file" do
          assert response.header["Content-Disposition"] =~ /\.log"$/
        end
      end
    end

    unauthorized :post, :create, project_id: 1
    unauthorized :delete, :destroy, project_id: 1, id: 1
  end

  as_a_deployer do
    describe "a POST to :create" do
      setup do
        JobExecution.stubs(:start_job).with('master', job)

        post :create, commands: { ids: [] }, job: {
          command: command,
          commit: "master"
        }, project_id: project.to_param
      end

      let(:params) 

      it "redirects to the job path" do
        assert_redirected_to project_job_path(project, job)
      end

      it "creates a job" do
        assert_equal [["master", [], command]], execute_called
      end
    end

    describe "a DELETE to :destroy" do
      describe "with a job owned by the deployer" do
        setup do
          Job.any_instance.stubs(:started_by?).returns(true)

          delete :destroy, project_id: project.to_param, id: job
        end

        it "responds with 200" do
          response.status.must_equal(200)
        end
      end

      describe "with a job not owned by the deployer" do
        setup do
          Job.any_instance.stubs(:started_by?).returns(false)
          User.any_instance.stubs(:is_admin?).returns(false)

          delete :destroy, project_id: project.to_param, id: job
        end

        it "responds with 403" do
          response.status.must_equal(403)
        end
      end
    end
  end

  as_a_admin do
    describe "a DELETE to :destroy" do
      describe "with a valid job" do
        setup do
          delete :destroy, project_id: project.to_param, id: job
        end

        it "responds ok" do
          response.status.must_equal(200)
        end
      end
    end
  end
end
