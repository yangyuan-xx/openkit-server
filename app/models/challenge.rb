=begin
  # Send myself a challenge from Todd:
  >
  > challenge = Challenge.new(sender_id: 119941, receiver_ids:[119979], leaderboard: Leaderboard.first, app: App.find(552), sandbox: true)
  > challenge.save
=end
class Challenge

  attr_accessor :sender_id, :receiver_ids, :leaderboard, :challenge_uuid, :sandbox
  attr_accessor :app

  def errors
    @errors ||= []
  end

  def notices
    @notices ||= []
  end


  def initialize(h={})
    h && h.each do |name, value|
      send("#{name}=", value) if respond_to? name.to_sym
    end
  end

  def save
    errors.push "sender_id is required"               unless sender_id
    errors.push "receiver_ids is required"            unless !receiver_ids.blank?
    errors.push "leaderboard is required"             unless leaderboard
    errors.push "app is required"                     unless app
    errors.push "sender_id is not an accessible user" unless app.developer.has_user?(sender_id)

    @safe_receivers = []
    receiver_ids.each do |r_id|
      if app.developer.has_user?(r_id)
        @safe_receivers << r_id
      end
    end

    if errors.empty?
      if !enqueue
        errors.push "Could not enqueue challenge"
      end
    end
    errors.empty?
  end

  private
  def enqueue
    tokens = []
    sender = User.find_by_id(sender_id)
    if sender
      @safe_receivers.each do |r_id|
        u = User.find_by_id(r_id)
        if u
          t = u.send(tokens_association).where(app_id: app.id).uniq_by(&:apns_token)
          tokens |= t if !t.empty?
        end
      end

      if !tokens.empty?
        tokens.each do |token|
          package = {aps: {alert: "#{sender.nick} just beat your #{leaderboard.name} score.", sound: "default"}, challenge_uuid: challenge_uuid}
          entry = [app.app_key, token.apns_token, package]
          OKRedis.connection.lpush(pn_queue_key, entry.to_json)
        end
      end
    end

    true
  end

  def pn_queue_key
    sandbox ? 'sandbox_pn_queue' : 'pn_queue'
  end

  def tokens_association
    sandbox ? :sandbox_tokens : :tokens
  end
end
