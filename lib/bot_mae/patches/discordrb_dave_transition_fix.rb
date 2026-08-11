require "discordrb"

module Discordrb::Voice
  class VoiceWS
    private

    def process_dave_commit(transition_id, commit)
      @bot.debug("DAVE: Processing MLS commit for transition #{transition_id}")
      result = dave_control_session.process_commit(commit)

      if result.failed?
        Discordrb::LOGGER.warn("DAVE: Received invalid MLS commit for transition #{transition_id}")
        handle_invalid_dave_group(transition_id)
        return
      end

      if result.ignored?
        @bot.debug("DAVE: Ignored MLS commit for transition #{transition_id}")
        return
      end

      track_pending_transition(transition_id, activate_pending_session: !@pending_dave_session.nil?)
      @bot.debug("DAVE: Transition #{transition_id} is ready")
      send_dave_ready_for_transition(transition_id)
    rescue Discordrb::Voice::DAVE::Error => e
      Discordrb::LOGGER.warn("DAVE: Failed to process MLS commit for transition #{transition_id}: #{e.message}")
      handle_invalid_dave_group(transition_id)
    end
  end
end
