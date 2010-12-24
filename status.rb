class Twitt::Status < ActiveRecord::Base

  belongs_to :geek, :class_name => "Twitt::Geek",  :foreign_key => "geek_id"

  scope :not_processed, includes(:geek).where('twitt_statuses.processed = ?', false).order('twitt_statuses.id DESC')

  def self.statuses(between = [])
    if between.present?
      raise ArgumentError if between.size != 2
      start, finish = between
      start = start.to_time
      finish = finish.to_time
      between = ['twitt_statuses.created_at BETWEEN ? AND ?', start, finish]
    end

    projects = {}
    geeks = {}

    Project.accepteds.select{|x| x.hashtag != nil}.each do |project|
      projects[project.hashtag] = {'#up' => 0, '#down' => 0}
    end

    statuses = self.not_processed.where(between)

    statuses.each do |status|
      nick = status.geek.nick
      project_hashtag = status.project_hashtag

      if project_hashtag.present?
        Twitt::Status.process_geek!(nick, status, geeks)
        if ['#up','#down'].include?(status.hashtag_vote) and ((geeks[nick]['#up'] <= 3 and status.hashtag_vote == '#up') or (geeks[nick]['#down'] <= 1 and status.hashtag_vote == '#down'))
          projects[project_hashtag][status.hashtag_vote] += status.vote
        end
      end
      status.update_attribute(:processed, true)
    end
    projects
  end


  def hashtag_vote
    hash_tag_vote = nil
    self.hashtags.each do |hashtag|
      if Vote::HASHTAGS.include?(hashtag)
        hash_tag_vote = hashtag
        break
      end
    end
    hash_tag_vote
  end

  def vote
    case self.hashtag_vote
    when '#up' then 1
    when '#down' then -1
    else 0
    end
  end

  private
  def self.process_geek!(nick, status, geeks)
    if geeks[nick].present?
      geeks[nick][status.hashtag_vote] += 1
    else
      geeks[nick] = {}
      geeks[nick]['#up'] = 0
      geeks[nick]['#down'] = 0
      geeks[nick][status.hashtag_vote] = 1
    end
  end
end
