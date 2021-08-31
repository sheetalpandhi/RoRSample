class Event < ApplicationRecord
  attr_accessor :friends, :current_latitude, :current_longitude

  belongs_to :user
  has_many :event_users, dependent: :destroy
  has_many :guests, through: :event_users, source: :user
  has_many :messages, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  # has_many_attached :photos à décommenter à la configu de Cloudinary

  before_validation :set_attributes

  # validates :emoji, presence: true
  # validates :address, presence: true
  validates :date_time, presence: true

  enum status: %i[incompleted completed past]

  EMOJI = { drink: '🍺', wine: '🍷', coffee: '☕️',
            brunch: '🥞', eat: '🍔', movies: '🍿',
            party: '🎉', Rrrr: '🍑', dance: '💃',
            yoga: '🧘‍♀️', sport: '💪', run: '🏃‍♂️',
            concert: '🎷', available: '🙋‍♂️', theater: '🎭',
            pingpong: '🏓', petanque: '🎱', gym: '🏋️‍♂️',
            basketball: '🏀', volleyball: '🏐', tennis: '🎾',
            spikeball: '🥎', football: '⚽️', rugby: '🏈',
            kitesurf: '🪁', surf: '🏄', climb: '🧗‍♀️',
            walk: '🚶‍♂️', swim: '🏊‍♀️', bike: '🚴‍♀️',
            canoe: '🛶', hike: '⛰', camp: '⛺️',
            boxe: '🥊', beach: '🏖', bbq: '🥩',
            boardgame: '🎲', geek: '🎮', bowling: '🎳',
            challenge: '🏆', work: '👩‍💻', standup: '🎙',
            trip: '🚌', festival: '🎪', weekend: '🏠',
            help: '📦', birthday: '🎁', exhibition: '🎨',
            shop: '🛍', cook: '👨‍🍳', wellbeing: '💅',
            beerpong: '🥤', smoke: '🚬', pet: '🐶'
            }

  # Geocoding
  geocoded_by :address
  after_validation :geocode, if: :will_save_change_to_address?

  def title
    Event::EMOJI.find { |k, v| v == emoji }&.first.to_s
  end

  def time_left
    seconds_diff = (Time.now - date_time).to_i.abs

    # Calculate the hours left
    hours = seconds_diff / 3600
    seconds_diff -= hours * 3600

    # Calculate the minutes left
    minutes = seconds_diff / 60

    # Calculate the seconds left
    seconds = seconds_diff % 60

    # Return a nice string that display time left format: hh:mm
    "#{hours.to_s.rjust(2, '0')}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
  end

  def is_over?
    Time.now > self.date_time + (5 * 3600)
  end

  def format_date
    if date_time >= DateTime.now.beginning_of_day && date_time < DateTime.now
      "NOW"
    elsif date_time >= DateTime.now.beginning_of_day && date_time >= DateTime.now
      if date_time <= DateTime.now.end_of_day
        "#{date_time.strftime('%H:%M')}"
      elsif (date_time - DateTime.now)/ 86400 < 6
        "#{date_time.strftime('%A').upcase.slice(0,3)}"
      elsif (date_time.year == DateTime.now.year)
        "#{date_time.strftime('%d/%m')}"
      else
        "#{date_time.strftime('%Y')}"
      end
    else
      "#{((Time.now - date_time)/86400).to_i}days ago"
    end
  end

  private

  def set_attributes
    # self.emoji = "🍺" if self.emoji.blank?
    # self.address = "75017, Paris" if self.address.blank?
    self.description = "Shared his plan with you" if status.blank?
    self.date_time = DateTime.now if date_time.blank?
    self.status = "incompleted" if status.blank?
  end
end
