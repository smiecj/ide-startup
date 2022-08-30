import { Injector } from '@opensumi/di';
import { ClientApp, IClientAppOpts } from '@opensumi/ide-core-browser';
import { ToolbarActionBasedLayout } from '@opensumi/ide-core-browser/lib/components';
import { MenuBarContribution } from './menu-bar/menu-bar.contribution';
import { StatusBarContribution } from './status-bar/status-bar.contribution';

export async function renderApp(opts: IClientAppOpts) {
  const injector = new Injector();
  injector.addProviders(StatusBarContribution);
  injector.addProviders(MenuBarContribution);

  const hostname = window.location.hostname;
  const query = new URLSearchParams(window.location.search);
  // 线上的静态服务和 IDE 后端是一个 Server
  const serverPort = process.env.DEVELOPMENT ? (process.env.IDE_SERVER_PORT || 8000) : window.location.port;
  const staticServerPort = process.env.DEVELOPMENT ? 8080 : window.location.port;
  const webviewEndpointPort = process.env.DEVELOPMENT ? 8899 : window.location.port;
  opts.workspaceDir = '/home/hovyan';

  opts.extensionDir = opts.extensionDir || process.env.EXTENSION_DIR;
  opts.injector = injector;
  opts.wsPath = process.env.WS_PATH || window.location.protocol == 'https:' ? `wss://${hostname}:${serverPort}` : `ws://${hostname}:${serverPort}`;

  opts.wsPath = opts.wsPath + 'NB_PREFIX';
  opts.staticServicePath = (window.location.protocol == 'https:' ? 'https://' : 'http://') + `${hostname}:${serverPort}` + 'NB_PREFIX';
  opts.extWorkerHost = (window.location.protocol == 'https:' ? 'https://' : 'http://') + `${hostname}:${staticServerPort}` + 'NB_PREFIX' + '/worker-host.js'

  const anotherHostName = process.env.WEBVIEW_HOST || hostname;
  opts.webviewEndpoint = (window.location.protocol == 'https:' ? 'https://' : 'http://') + `${anotherHostName}:${webviewEndpointPort}` + 'NB_PREFIX' + '/webview';
  
  opts.layoutComponent = ToolbarActionBasedLayout;
  const app = new ClientApp(opts);

  app.fireOnReload = () => {
    window.location.reload();
  };

  app.start(document.getElementById('main')!, 'web');
}
