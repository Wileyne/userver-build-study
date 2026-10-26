import handlers.hello_pb2_grpc as hello_services
import pytest

from testsuite.databases.pgsql import discover

pytest_plugins = [
    'pytest_userver.plugins.core',
    'pytest_userver.plugins.postgresql',
    'pytest_userver.plugins.mongo',
    'pytest_userver.plugins.grpc',
]


MONGO_COLLECTIONS = {
    'hello_users': {
        'settings': {
            'collection': 'hello_users',
            'connection': 'admin',
            'database': 'admin',
        },
        'indexes': [],
    },
}


@pytest.fixture(scope='session')
def mongodb_settings():
    return MONGO_COLLECTIONS




@pytest.fixture
def grpc_service(grpc_channel, service_client):
    return hello_services.HelloServiceStub(grpc_channel)




@pytest.fixture(scope='session')
def initial_data_path(service_source_dir):
    """Path for find files with data"""
    return [
        service_source_dir / 'postgresql/data',
    ]


@pytest.fixture(scope='session')
def pgsql_local(service_source_dir, pgsql_local_create):
    """Create schemas databases for tests"""
    databases = discover.find_schemas(
        'benchmark_service',
        [service_source_dir.joinpath('postgresql/schemas')],
    )
    return pgsql_local_create(list(databases.values()))
