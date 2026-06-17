import GRDB

enum Migrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1") { db in
            try db.create(table: "clutch_events", ifNotExists: true) { t in
                t.column("id",           .text).primaryKey()
                t.column("timestamp",    .datetime).notNull()
                t.column("device_name",  .text).notNull()
                t.column("volume",       .double).notNull()
                t.column("app_name",     .text).notNull()
                t.column("mode",         .text).notNull()
                t.column("risk_score",   .integer).notNull()
            }
        }
        
        return migrator
    }
}
