#pragma once

#include <userver/components/component.hpp>

#include <handlers/hello_service.usrv.pb.hpp>

namespace benchmark_service {

class HelloGrpc final : public handlers::api::HelloServiceBase::Component {
public:
    static constexpr std::string_view kName = "handler-hello-grpc";

    HelloGrpc(const userver::components::ComponentConfig&, const userver::components::ComponentContext&);

    SayHelloResult SayHello(CallContext&, handlers::api::HelloRequest&&) override;
};

}  // namespace benchmark_service