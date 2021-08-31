class EventsController < ApplicationController
  before_action :find_event,
                only: %i[show edit_what update_what edit_address update_address
                  edit_when update_when edit_friends update_friends destroy edit
                  update chatroom guests edit_guests update_guests]
  before_action :find_last_request_path, only: [:show, :chatroom, :guests]

  skip_before_action :authenticate_user!, only: [:show]

  def index
    @events = policy_scope(current_user.all_events.includes(:user))

    morning_midnight = DateTime.now.beginning_of_day
    evening_midnight = DateTime.now.end_of_day

    @past_events = @events.where("date_time < ?", morning_midnight)

    @ongoing_events = @events.where("date_time >= ?", morning_midnight)
                             .where("date_time < ?", DateTime.now)

    @upcoming_events = @events.where("date_time >= ?", DateTime.now)
                              .where("date_time < ?", evening_midnight)

    @later_events = @events.where("date_time >= ?", evening_midnight)
                           .order(:date_time).reverse
  end

  def show
    if current_user
      @guest_invited_notifications = current_user.notifications.includes(notifiable: :event).where(title: "guest_invited", read: false)
      @guest_invited_notifications.each { |n| n.update(read: true) if n.notifiable.event == @event }

      @event_updated_notifications = current_user.notifications.where(notifiable: @event, title: "event_updated", read: false)
      @event_updated_notifications.each { |n| n.update(read: true) }
    end

    @user_is_host = @event.user == current_user
    @host_first_message = Message.where(event: @event, user: @event.user)
    @message = Message.new

    @last_message = @event.messages.last
  end

  def create
    @event = Event.new
    authorize @event
    @event.user = current_user
    @event.save
    redirect_to edit_what_event_path(@event)
  end

  def edit_what
  end

  def update_what
    if @event.update(event_params)
      redirect_to edit_friends_event_path(@event)
    else
      render :edit_what
    end
  end

  def edit_friends
    @friends = current_user.approved_friends.includes(avatar_attachment: :blob)
    events_i_went = policy_scope(current_user.events_i_went)
    @people_i_ve_met = current_user.people_i_ve_met(events_i_went)
  end

  def update_friends
    @event.event_users.where(role: "visitor").destroy_all
    params.dig(:event, :friends)&.each { |user_id| @event.event_users.create(user_id: user_id) }
    redirect_to edit_address_event_path(@event)
  end

  def update_address
    if @event.update(event_params)
      @event.event_users.each { |guest| guest.notifications.create(user: guest.user, title: "guest_invited", from: current_user) }
      @event.event_users.create(user: current_user, status: :confirmed, role: :host)
      @event.completed!

      redirect_to root_path
    else
      render :edit_address
    end
  end

  def destroy
    @event.destroy
    redirect_to root_path
  end

  def chatroom
    @event_message_notifications = current_user.notifications.includes(notifiable: :event).where(title: "event_message", read: false)
    @event_message_notifications.each { |n| n.update(read: true) if n.notifiable.event == @event }

    @message = Message.new
    @host_first_message = Message.where(event: @event, user: @event.user)
    @last_message = @event.messages.last
  end

  def guests
    @guest_coming_notifications = current_user.notifications.includes(notifiable: :event).where(title: "guest_coming", read: false)
    @guest_coming_notifications.each { |n| n.update(read: true) if n.notifiable.event == @event }
    
    @co_hosting_notifications = current_user.notifications.includes(notifiable: :event).where(title: "co_hosting", read: false)
    @co_hosting_notifications.each { |n| n.update(read: true) if n.notifiable.event == @event }

    @guests = @event.event_users
                    .includes(user: [avatar_attachment: :blob])
                    .order_by_status
                    .order("users.first_name")

    @confirmed_or_pending_guests = @guests.where.not(status: "declined")
    @last_message = @event.messages.last
  end

  def edit_guests
    host_and_co_hosts = @event.event_users.where(role: "host").includes(:user).map {|guest| guest.user}
    friends = current_user.approved_friends.includes(avatar_attachment: :blob)
    @friends_no_cohosts = friends - host_and_co_hosts
    events_i_went = policy_scope(current_user.events_i_went)
    people_i_ve_met = current_user.people_i_ve_met(events_i_went)
    @people_i_ve_met_no_cohosts = people_i_ve_met - host_and_co_hosts
  end

  def update_guests
    guests_id = @event.event_users.pluck(:user_id)
    friends_id = current_user.friends.pluck(:id)
    @saved_friends = guests_id - friends_id

    params.dig(:event, :friends)&.each do |user_id|
      next if guests_id.include?(user_id.to_i)
      guest = @event.event_users.create(event: @event, user_id: user_id)
      guest.notifications.create(user: guest.user, title: "guest_invited", from: current_user)
    end

    guests_id_updated = params.dig(:event, :friends)&.map(&:to_i)
    @event.event_users.each do |guest|
      next if guests_id_updated&.include?(guest.user.id)
      next if @saved_friends&.include?(guest.user.id)
      next if guest.user.user_is_host?(@event)
      next if guest.user.user_is_cohost?(@event)

      guest.notifications.destroy_all
      guest.destroy
    end

    redirect_to guests_event_path(@event)
  end

  def edit_cohosts
    @event = Event.find(params[:id])
    @guests = @event.event_users.includes(:user).map(&:user)
    authorize @event
  end

  def update_cohosts
    @event = Event.find(params[:id])
    authorize @event
    hosts_id = @event.event_users.select {|g| g.user.user_is_cohost?(@event)}.pluck(:user_id)

    params.dig(:event, :friends)&.each do |user_id|
      next if hosts_id.include?(user_id.to_i)
      cohost = @event.event_users.find_by(event: @event, user_id: user_id)
      cohost.update(role: "host", status: "confirmed")
      cohost.notifications.create(user: cohost.user, title: "co_hosting", from: current_user)
    end

    hosts_id_updated = params.dig(:event, :friends)&.map(&:to_i)
      @event.event_users.each do |guest|
        next if hosts_id_updated&.include?(guest.user.id)
        next if @saved_friends&.include?(guest.user.id)
        next if guest.user.user_is_host?(@event)
        next if @event.event_users.find_by(user_id: guest.user_id).role != "host"

        guest.notifications.destroy_all
        @event.event_users.find_by(user_id: guest.user_id).update(role: "visitor", status: "pending")
      end

    redirect_to guests_event_path(@event)
  end

  def edit
  end

  def update
    @event.event_users.each do |guest|
      next if guest.role == "host" && guest.user_id == current_user.id
      next if guest.status == "declined"

      unless guest.user.notifications.find { |n| n.notifiable == @event && n.read == false }
        @event.notifications.create(user: guest.user, title: "event_updated")
      end
    end

    @event.update(open: params.dig(:event, :open) == '1')

    redirect_to event_path(@event) if @event.update(event_params)
  end

  private

  def find_event
    @event = Event.find(params[:id])
    authorize @event
  end

  def event_params
    strong_params = params.require(:event).permit(:emoji, :address, :date_time, :status)
    strong_params[:emoji] = Event::EMOJI[strong_params[:emoji].to_sym] if strong_params[:emoji]
    strong_params
  end

  def find_last_request_path
    session[:history].empty? ? @previous_request_fullpath = "/" : @previous_request_fullpath = session[:history].last
  end
end
