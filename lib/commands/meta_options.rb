# this class defines the valid meta options we allow
# such as the role types allowed, apps allowed, environments allowed
#
module Commands
  class MetaOptions
    # the roles that a given server can play
    # only one role per server is allowed.  If we
    # need custom functionality we define a role that
    # has the functionality we need.  For example, we
    # might have a role DB that gets a local db and redis server
    # but we might want to have a redis-slave role that defines
    # a machine that runs as a redis slave but does not get the
    # db.  The meaning of the roles is defined in the chef script
    # mapping from a role to recipes
    def self.roles
      [:app_master, :app, :db, :util, :redis_slave, :solo]
    end

    def self.availability_zones
      ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
    end

    # the valid apps we can deploy
    def self.apps
      [:photos, :zza, :rollup]
    end

  end
end