
"""Creates a Compute Instance with the provided metadata."""

COMPUTE_URL_BASE = 'https://www.googleapis.com/compute/v1/'


def GlobalComputeUrl(project, collection, name):
  return ''.join([COMPUTE_URL_BASE, 'projects/', project,
                  '/global/', collection, '/', name])


def ZonalComputeUrl(project, zone, collection, name):
  return ''.join([COMPUTE_URL_BASE, 'projects/', project,
                  '/zones/', zone, '/', collection, '/', name])


def GenerateConfig(context):
  """Generate configuration."""

  name_prefix = context.env['deployment'] + '-' + context.env['name']

  instance = {
      'zone': context.properties['zone'],
      'machineType': ZonalComputeUrl(
          context.env['project'], context.properties['zone'], 'machineTypes',
          'f1-micro'),
      'metadata': {
          'items': [{
              'key': 'startup-script',
              'value': context.properties['startup-script']
          }]
      },
      'tags': {
        'items': ["http-server"]
      },
      'disks': [{
          'deviceName': 'boot',
          'type': 'PERSISTENT',
          'autoDelete': True,
          'boot': True,
          'initializeParams': {
              'diskName': name_prefix + '-disk',
              'sourceImage': GlobalComputeUrl(
                  'debian-cloud', 'images', 'family/debian-11'
                  )
              },
          }],
      'networkInterfaces': [{
          'accessConfigs': [{
              'name': 'external-nat',
              'type': 'ONE_TO_ONE_NAT'
              }],
          'network': GlobalComputeUrl(
              context.env['project'], 'networks', 'default')
          }]
      }

  # Resources to return.
  resources = {
      'resources': [{
          'name': name_prefix + '-vm',
          'type': 'compute.v1.instance',
          'properties': instance
          }]
      }

  return resources