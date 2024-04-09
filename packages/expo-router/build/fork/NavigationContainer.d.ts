import { type NavigationContainerProps, type NavigationContainerRef } from '@react-navigation/core';
import { DocumentTitleOptions, LinkingOptions, LocaleDirection } from '@react-navigation/native';
import * as React from 'react';
declare global {
    var REACT_NAVIGATION_DEVTOOLS: WeakMap<NavigationContainerRef<any>, {
        readonly linking: LinkingOptions<any>;
    }>;
}
type Props<ParamList extends object> = NavigationContainerProps & {
    direction?: LocaleDirection;
    linking?: LinkingOptions<ParamList>;
    fallback?: React.ReactNode;
    documentTitle?: DocumentTitleOptions;
};
<<<<<<< HEAD
declare const NavigationContainer: <RootParamList extends object = ReactNavigation.RootParamList>(props: NavigationContainerProps & {
    theme?: Theme | undefined;
    linking?: LinkingOptions<RootParamList> | undefined;
    fallback?: React.ReactNode;
    documentTitle?: DocumentTitleOptions | undefined;
    onReady?: (() => void) | undefined;
} & {
    ref?: React.Ref<NavigationContainerRef<RootParamList>> | undefined;
=======
export declare const NavigationContainer: <RootParamList extends object = ReactNavigation.RootParamList>(props: Props<RootParamList> & {
    ref?: React.Ref<NavigationContainerRef<RootParamList>>;
>>>>>>> 84de81f5990 (fix errors)
}) => React.ReactElement;
export {};
//# sourceMappingURL=NavigationContainer.d.ts.map