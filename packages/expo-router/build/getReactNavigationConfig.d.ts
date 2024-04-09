import type { RouteNode } from './Route';
import { ExpoLinkingOptions } from './getLinkingConfig';
export type Screen = string | {
    path: string;
    screens: Record<string, Screen>;
    _route?: RouteNode;
    initialRouteName?: string;
};
export declare function getReactNavigationScreensConfig(nodes: RouteNode[], metaOnly: boolean): Record<string, Screen>;
<<<<<<< HEAD
export declare function getReactNavigationConfig(routes: RouteNode, metaOnly: boolean): {
    initialRouteName: string | undefined;
    screens: Record<string, Screen>;
};
=======
export declare function getReactNavigationConfig(routes: RouteNode, metaOnly: boolean): ExpoLinkingOptions['config'];
>>>>>>> 84de81f5990 (fix errors)
//# sourceMappingURL=getReactNavigationConfig.d.ts.map