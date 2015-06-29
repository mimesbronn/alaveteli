# -*- encoding : utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe WidgetsController do

    include LinkToHelper

    describe 'GET show' do

        before do
            @info_request = FactoryGirl.create(:info_request)
            AlaveteliConfiguration.stub!(:enable_widgets).and_return(true)
        end

        it 'should render the widget template' do
            get :show, :request_id => @info_request.id
            expect(response).to render_template('show')
        end

        it 'should find the info request' do
            get :show, :request_id => @info_request.id
            assigns[:info_request].should == @info_request
        end

        it 'should create a track thing for the request' do
            get :show, :request_id => @info_request.id
            assigns[:track_thing].info_request.should == @info_request
        end

        it 'should assign the request status' do
            get :show, :request_id => @info_request.id
            assigns[:status].should == @info_request.calculate_status
        end

        it 'assigns the count of follows the request has' do
            TrackThing.delete_all
            WidgetVote.delete_all

            track = TrackThing.create_track_for_request(@info_request)
            track.track_medium = 'email_daily'
            track.tracking_user = FactoryGirl.create(:user)
            track.save!

            3.times do
                @info_request.widget_votes.create(:cookie => SecureRandom.hex(10))
            end

            get :show, :request_id => @info_request.id

            # Count should be 5
            # 1 for the request's owning user
            # 1 track thing
            # 3 widget votes
            expect(assigns[:count]).to eq(5)
        end

        it 'should not send an x-frame-options header' do
            get :show, :request_id => @info_request.id
            response.headers["X-Frame-Options"].should be_nil
        end

        context 'for a non-logged-in user with a tracking cookie' do

            it 'assigns the cookie to tracking_cookie' do
                request.cookies['widget_vote'] = mock_cookie
                get :show, :request_id => @info_request.id
                expect(assigns[:tracking_cookie]).to eq(mock_cookie)
            end

        end

        context 'for a non-logged-in user without a tracking cookie' do

            it 'tracking_cookie will be nil' do
                request.cookies['widget_vote'] = nil
                get :show, :request_id => @info_request.id
                expect(assigns[:tracking_cookie]).to be_nil
            end

        end

        context 'for a logged in user with tracks' do

            it 'finds the existing track thing' do
                user = FactoryGirl.create(:user)
                track = TrackThing.create_track_for_request(@info_request)
                track.track_medium = 'email_daily'
                track.tracking_user = user
                track.save!
                session[:user_id] = user.id

                get :show, :request_id => @info_request.id

                expect(assigns[:existing_track]).to eq(track)
            end

        end

        context 'for a logged in user without tracks' do

            it 'does not find existing track things' do
                TrackThing.delete_all
                user = FactoryGirl.create(:user)
                session[:user_id] = user.id

                get :show, :request_id => @info_request.id

                expect(assigns[:existing_track]).to be_nil
            end

        end

        context 'when widgets are not enabled' do

            it 'raises ActiveRecord::RecordNotFound' do
                AlaveteliConfiguration.stub!(:enable_widgets).and_return(false)
                lambda{ get :show, :request_id => @info_request.id }.should
                    raise_error(ActiveRecord::RecordNotFound)
            end

        end

        context "when the request's prominence is not 'normal'" do

            it 'should return a 403' do
                @info_request.prominence = 'hidden'
                @info_request.save!
                get :show, :request_id => @info_request.id
                response.code.should == "403"
            end

        end

    end

    describe 'GET new' do

        before do
            @info_request = FactoryGirl.create(:info_request)
            AlaveteliConfiguration.stub!(:enable_widgets).and_return(true)
        end

        it 'should render the create widget template' do
            get :new, :request_id => @info_request.id
            expect(response).to render_template('new')
        end

        it 'should find the info request' do
            get :new, :request_id => @info_request.id
            assigns[:info_request].should == @info_request
        end

        context 'when widgets are not enabled' do

            it 'raises ActiveRecord::RecordNotFound' do
                AlaveteliConfiguration.stub!(:enable_widgets).and_return(false)
                lambda{ get :new, :request_id => @info_request.id }.should
                    raise_error(ActiveRecord::RecordNotFound)
            end

        end

        context "when the request's prominence is not 'normal'" do

            it 'should return a 403' do
                @info_request.prominence = 'hidden'
                @info_request.save!
                get :show, :request_id => @info_request.id
                response.code.should == "403"
            end

        end

    end

    describe 'PUT update' do

        before do
            @info_request = FactoryGirl.create(:info_request)
            AlaveteliConfiguration.stub!(:enable_widgets).and_return(true)
        end

        it 'should find the info request' do
            put :update, :request_id => @info_request.id
            assigns[:info_request].should == @info_request
        end

        it 'should redirect to the track path for the info request' do
            put :update, :request_id => @info_request.id
            track_thing = TrackThing.create_track_for_request(@info_request)
            expect(response).to redirect_to(do_track_path(track_thing))
        end

        context 'for a non-logged-in user without a tracking cookie' do

            it 'sets a tracking cookie' do
                SecureRandom.stub!(:hex).and_return(mock_cookie)
                put :update, :request_id => @info_request.id
                expect(cookies[:widget_vote]).to eq(mock_cookie)
            end

            it 'creates a widget vote' do
                SecureRandom.stub!(:hex).and_return(mock_cookie)
                votes = @info_request.
                            widget_votes.
                                where(:cookie => mock_cookie)

                put :update, :request_id => @info_request.id

                expect(votes).to have(1).item
            end

        end


        context 'for a non-logged-in user with a tracking cookie' do

            it 'retains the existing tracking cookie' do
                request.cookies['widget_vote'] = mock_cookie
                put :update, :request_id => @info_request.id
                expect(cookies[:widget_vote]).to eq(mock_cookie)
            end

            it 'creates a widget vote' do
                request.cookies['widget_vote'] = mock_cookie
                votes = @info_request.
                            widget_votes.
                                where(:cookie => mock_cookie)

                put :update, :request_id => @info_request.id

                expect(votes).to have(1).item
            end

        end

        context 'when widgets are not enabled' do

            it 'raises ActiveRecord::RecordNotFound' do
                AlaveteliConfiguration.stub!(:enable_widgets).and_return(false)
                lambda{ put :update, :request_id => @info_request.id }.should
                    raise_error(ActiveRecord::RecordNotFound)
            end

        end

        context "when the request's prominence is not 'normal'" do

            it 'should return a 403' do
                @info_request.prominence = 'hidden'
                @info_request.save!
                put :show, :request_id => @info_request.id
                response.code.should == "403"
            end

        end

    end

end

def mock_cookie
    '0300fd3e1177127cebff'
end
