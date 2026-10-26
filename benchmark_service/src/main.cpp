#include <userver/clients/dns/component.hpp>
#include <userver/clients/http/component_list.hpp>
#include <userver/components/component.hpp>
#include <userver/components/component_list.hpp>
#include <userver/components/minimal_server_component_list.hpp>
#include <userver/congestion_control/component.hpp>
#include <userver/server/handlers/ping.hpp>
#include <userver/server/handlers/tests_control.hpp>
#include <userver/testsuite/testsuite_support.hpp>

#include <userver/storages/mongo/component.hpp>
#include <userver/storages/postgres/component.hpp>
#include <userver/ugrpc/server/component_list.hpp>

#include <userver/utils/daemon_run.hpp>

#include <hello.hpp>
#include <hello_grpc.hpp>
#include <hello_mongo.hpp>
#include <hello_postgres.hpp>

int main(int argc, char* argv[]) {
    auto component_list =
        userver::components::MinimalServerComponentList()
            .Append<userver::server::handlers::Ping>()
            .Append<userver::components::TestsuiteSupport>()
            .AppendComponentList(userver::clients::http::ComponentList())
            .Append<userver::clients::dns::Component>()
            .Append<userver::server::handlers::TestsControl>()
            .Append<userver::congestion_control::Component>()
            .Append<benchmark_service::Hello>()
            .Append<userver::components::Postgres>("postgres-db-1")
            .Append<benchmark_service::HelloPostgres>()
            .Append<userver::components::Mongo>("mongo-db-1")
            .Append<benchmark_service::HelloMongo>()
            .AppendComponentList(userver::ugrpc::server::MinimalComponentList())
            .Append<benchmark_service::HelloGrpc>()
        ;

    return userver::utils::DaemonMain(argc, argv, component_list);
}
