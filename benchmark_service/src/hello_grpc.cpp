#include <hello_grpc.hpp>

#include <greeting.hpp>

namespace benchmark_service {

HelloGrpc::HelloGrpc(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context
)
    : handlers::api::HelloServiceBase::Component(config, component_context) {}

HelloGrpc::SayHelloResult HelloGrpc::SayHello(CallContext&, handlers::api::HelloRequest&& request) {
    handlers::api::HelloResponse response;
    response.set_text(SayHelloTo(request.name(), UserType::kFirstTime));
    return response;
}

}  // namespace benchmark_service