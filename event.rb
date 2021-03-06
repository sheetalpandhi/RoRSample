class Event < ApplicationRecord
  attr_accessor :friends, :current_latitude, :current_longitude

  belongs_to :user
  has_many :event_users, dependent: :destroy
  has_many :guests, through: :event_users, source: :user
  has_many :messages, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  # has_many_attached :photos ร  dรฉcommenter ร  la configu de Cloudinary

  before_validation :set_attributes

  # validates :emoji, presence: true
  # validates :address, presence: true
  validates :date_time, presence: true

  enum status: %i[incompleted completed past]

  EMOJI = { drink: '๐บ', wine: '๐ท', coffee: 'โ๏ธ',
            brunch: '๐ฅ', eat: '๐', movies: '๐ฟ',
            party: '๐', Rrrr: '๐', dance: '๐',
            yoga: '๐งโโ๏ธ', sport: '๐ช', run: '๐โโ๏ธ',
            concert: '๐ท', available: '๐โโ๏ธ', theater: '๐ญ',
            pingpong: '๐', petanque: '๐ฑ', gym: '๐๏ธโโ๏ธ',
            basketball: '๐', volleyball: '๐', tennis: '๐พ',
            spikeball: '๐ฅ', football: 'โฝ๏ธ', rugby: '๐',
            kitesurf: '๐ช', surf: '๐', climb: '๐งโโ๏ธ',
            walk: '๐ถโโ๏ธ', swim: '๐โโ๏ธ', bike: '๐ดโโ๏ธ',
            canoe: '๐ถ', hike: 'โฐ', camp: 'โบ๏ธ',
            boxe: '๐ฅ', beach: '๐', bbq: '๐ฅฉ',
            boardgame: '๐ฒ', geek: '๐ฎ', bowling: '๐ณ',
            challenge: '๐', work: '๐ฉโ๐ป', standup: '๐',
            trip: '๐', festival: '๐ช', weekend: '๐ ',
            help: '๐ฆ', birthday: '๐', exhibition: '๐จ',
            shop: '๐', cook: '๐จโ๐ณ', wellbeing: '๐',
            beerpong: '๐ฅค', smoke: '๐ฌ', pet: '๐ถ'
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
    # self.emoji = "๐บ" if self.emoji.blank?
    # self.address = "75017, Paris" if self.address.blank?
    self.description = "Shared his plan with you" if status.blank?
    self.date_time = DateTime.now if date_time.blank?
    self.status = "incompleted" if status.blank?
  end
end
