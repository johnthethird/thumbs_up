module ThumbsUp #:nodoc:
  module ActsAsVoter #:nodoc:

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def acts_as_voter

        # If a voting entity is deleted, keep the votes.
        # If you want to nullify (and keep the votes), you'll need to remove
        # the unique constraint on the [ voter, voteable ] index in the database.
        # has_many :votes, :as => :voter, :dependent => :nullify
        # Destroy votes when a user is deleted.
        has_many :votes, :as => :voter, :dependent => :destroy

        include ThumbsUp::ActsAsVoter::InstanceMethods
        extend  ThumbsUp::ActsAsVoter::SingletonMethods
      end
    end

    # This module contains class methods
    module SingletonMethods
    end

    # This module contains instance methods
    module InstanceMethods

      # Usage user.vote_count(:up)  # All +1 votes
      #       user.vote_count(:down) # All -1 votes
      #       user.vote_count()      # All votes

      def vote_count(for_or_against = :all)
        v = Vote.where(:voter_id => id).where(:voter_type => self.class.name)
        v = case for_or_against
          when :all   then v
          when :up    then v.where(:vote => 1)
          when :down  then v.where(:vote => 0)
        end
        v.count
      end

      def point_count(for_or_against = :all)
        v = Vote.where(:voter_id => id).where(:voter_type => self.class.name)
        v = case for_or_against
          when :all   then v.sum("points")
          when :up    then v.where(:vote => 1).sum("points")
          when :down  then v.where(:vote => 0).sum("points")
        end
      end

      def voted_for?(voteable)
        voted_which_way?(voteable, :up)
      end

      def voted_against?(voteable)
        voted_which_way?(voteable, :down)
      end

      def voted_on?(voteable)
        undecorated_voteable = undecorate(voteable)
        0 < Vote.where(
              :voter_id => self.id,
              :voter_type => self.class.name,
              :voteable_id => undecorated_voteable.id,
              :voteable_type => undecorated_voteable.class.name
            ).count
      end

      def vote_for(voteable, options = {})
        self.vote(voteable, options.merge({:direction => :up, :exclusive => false }))
      end

      def vote_against(voteable, options = {})
        self.vote(voteable, options.merge({:direction => :down, :exclusive => false }))
      end

      def vote_exclusively_for(voteable, options = {})
        self.vote(voteable, options.merge({:direction => :up, :exclusive => true }))
      end

      def vote_exclusively_against(voteable, options = {})
        self.vote(voteable, options.merge({:direction => :down, :exclusive => true }))
      end

      def vote(voteable, options = {})
        raise ArgumentError, "you must specify :up or :down in order to vote" unless options[:direction] && [:up, :down].include?(options[:direction].to_sym)
        undecorated_voteable = undecorate(voteable)
        if options[:exclusive]
          self.clear_votes(undecorated_voteable)
        end
        direction = (options[:direction].to_sym == :up)
        vote_val = direction ? 1 : 0
        points = (options[:points] || 1).to_i * (direction ? 1 : -1)
        v = Vote.new(:vote => vote_val, :voteable => undecorated_voteable, :voter => self, :points => points)
        v.save!
        undecorated_voteable.save(:validate => false)
        v
      end

      def clear_votes(voteable)
        undecorated_voteable = undecorate(voteable)
        Vote.where(
          :voter_id => self.id,
          :voter_type => self.class.name,
          :voteable_id => undecorated_voteable.id,
          :voteable_type => undecorated_voteable.class.name
        ).map(&:destroy)
        undecorated_voteable.save(:validate => false)
      end

      def voted_which_way?(voteable, direction)
        raise ArgumentError, "expected :up or :down" unless [:up, :down].include?(direction)
        undecorated_voteable = undecorate(voteable)
        0 < Vote.where(
              :voter_id => self.id,
              :voter_type => self.class.name,
              :vote => direction == :up ? 1 : 0,
              :voteable_id => undecorated_voteable.id,
              :voteable_type => undecorated_voteable.class.name
            ).count
      end

      # If voteable is a Draper-style object, get the undecorated object.
      def undecorate(voteable)
        voteable.decorated? ? voteable.source : voteable
      end

    end
  end
end