(function(){var At=Object.create,We=Object.defineProperty,Ht=Object.getOwnPropertyDescriptor,Lt=Object.getOwnPropertyNames,Bt=Object.getPrototypeOf,$t=Object.prototype.hasOwnProperty,ae=(e,t)=>()=>(t||e((t={exports:{}}).exports,t),t.exports),Nt=(e,t,n,o)=>{if(t&&typeof t=="object"||typeof t=="function")for(var i=Lt(t),s=0,l=i.length,g;s<l;s++)g=i[s],!$t.call(e,g)&&g!==n&&We(e,g,{get:(d=>t[d]).bind(null,g),enumerable:!(o=Ht(t,g))||o.enumerable});return e},Ye=(e,t,n)=>(n=e!=null?At(Bt(e)):{},Nt(t||!e||!e.__esModule?We(n,"default",{value:e,enumerable:!0}):n,e)),zt=ae((e=>{var t=Symbol.for("react.transitional.element"),n=Symbol.for("react.portal"),o=Symbol.for("react.fragment"),i=Symbol.for("react.strict_mode"),s=Symbol.for("react.profiler"),l=Symbol.for("react.consumer"),g=Symbol.for("react.context"),d=Symbol.for("react.forward_ref"),u=Symbol.for("react.suspense"),c=Symbol.for("react.memo"),h=Symbol.for("react.lazy"),p=Symbol.for("react.activity"),f=Symbol.iterator;function v(a){return a===null||typeof a!="object"?null:(a=f&&a[f]||a["@@iterator"],typeof a=="function"?a:null)}var w={isMounted:function(){return!1},enqueueForceUpdate:function(){},enqueueReplaceState:function(){},enqueueSetState:function(){}},D=Object.assign,T={};function H(a,b,k){this.props=a,this.context=b,this.refs=T,this.updater=k||w}H.prototype.isReactComponent={},H.prototype.setState=function(a,b){if(typeof a!="object"&&typeof a!="function"&&a!=null)throw Error("takes an object of state variables to update or a function which returns an object of state variables.");this.updater.enqueueSetState(this,a,b,"setState")},H.prototype.forceUpdate=function(a){this.updater.enqueueForceUpdate(this,a,"forceUpdate")};function I(){}I.prototype=H.prototype;function B(a,b,k){this.props=a,this.context=b,this.refs=T,this.updater=k||w}var y=B.prototype=new I;y.constructor=B,D(y,H.prototype),y.isPureReactComponent=!0;var L=Array.isArray;function A(){}var C={H:null,A:null,T:null,S:null},U=Object.prototype.hasOwnProperty;function K(a,b,k){var E=k.ref;return{$$typeof:t,type:a,key:b,ref:E!==void 0?E:null,props:k}}function J(a,b){return K(a.type,b,a.props)}function F(a){return typeof a=="object"&&a!==null&&a.$$typeof===t}function ie(a){var b={"=":"=0",":":"=2"};return"$"+a.replace(/[=:]/g,function(k){return b[k]})}var ee=/\/+/g;function te(a,b){return typeof a=="object"&&a!==null&&a.key!=null?ie(""+a.key):b.toString(36)}function q(a){switch(a.status){case"fulfilled":return a.value;case"rejected":throw a.reason;default:switch(typeof a.status=="string"?a.then(A,A):(a.status="pending",a.then(function(b){a.status==="pending"&&(a.status="fulfilled",a.value=b)},function(b){a.status==="pending"&&(a.status="rejected",a.reason=b)})),a.status){case"fulfilled":return a.value;case"rejected":throw a.reason}}throw a}function G(a,b,k,E,_){var $=typeof a;($==="undefined"||$==="boolean")&&(a=null);var M=!1;if(a===null)M=!0;else switch($){case"bigint":case"string":case"number":M=!0;break;case"object":switch(a.$$typeof){case t:case n:M=!0;break;case h:return M=a._init,G(M(a._payload),b,k,E,_)}}if(M)return _=_(a),M=E===""?"."+te(a,0):E,L(_)?(k="",M!=null&&(k=M.replace(ee,"$&/")+"/"),G(_,b,k,"",function(he){return he})):_!=null&&(F(_)&&(_=J(_,k+(_.key==null||a&&a.key===_.key?"":(""+_.key).replace(ee,"$&/")+"/")+M)),b.push(_)),1;M=0;var Q=E===""?".":E+":";if(L(a))for(var V=0;V<a.length;V++)E=a[V],$=Q+te(E,V),M+=G(E,b,k,$,_);else if(V=v(a),typeof V=="function")for(a=V.call(a),V=0;!(E=a.next()).done;)E=E.value,$=Q+te(E,V++),M+=G(E,b,k,$,_);else if($==="object"){if(typeof a.then=="function")return G(q(a),b,k,E,_);throw b=String(a),Error("Objects are not valid as a React child (found: "+(b==="[object Object]"?"object with keys {"+Object.keys(a).join(", ")+"}":b)+"). If you meant to render a collection of children, use an array instead.")}return M}function Z(a,b,k){if(a==null)return a;var E=[],_=0;return G(a,E,"","",function($){return b.call(k,$,_++)}),E}function ne(a){if(a._status===-1){var b=a._result;b=b(),b.then(function(k){(a._status===0||a._status===-1)&&(a._status=1,a._result=k)},function(k){(a._status===0||a._status===-1)&&(a._status=2,a._result=k)}),a._status===-1&&(a._status=0,a._result=b)}if(a._status===1)return a._result.default;throw a._result}var se=typeof reportError=="function"?reportError:function(a){if(typeof window=="object"&&typeof window.ErrorEvent=="function"){var b=new window.ErrorEvent("error",{bubbles:!0,cancelable:!0,message:typeof a=="object"&&a!==null&&typeof a.message=="string"?String(a.message):String(a),error:a});if(!window.dispatchEvent(b))return}else if(typeof process=="object"&&typeof process.emit=="function"){process.emit("uncaughtException",a);return}console.error(a)},re={map:Z,forEach:function(a,b,k){Z(a,function(){b.apply(this,arguments)},k)},count:function(a){var b=0;return Z(a,function(){b++}),b},toArray:function(a){return Z(a,function(b){return b})||[]},only:function(a){if(!F(a))throw Error("React.Children.only expected to receive a single React element child.");return a}};e.Activity=p,e.Children=re,e.Component=H,e.Fragment=o,e.Profiler=s,e.PureComponent=B,e.StrictMode=i,e.Suspense=u,e.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE=C,e.__COMPILER_RUNTIME={__proto__:null,c:function(a){return C.H.useMemoCache(a)}},e.cache=function(a){return function(){return a.apply(null,arguments)}},e.cacheSignal=function(){return null},e.cloneElement=function(a,b,k){if(a==null)throw Error("The argument must be a React element, but you passed "+a+".");var E=D({},a.props),_=a.key;if(b!=null)for($ in b.key!==void 0&&(_=""+b.key),b)!U.call(b,$)||$==="key"||$==="__self"||$==="__source"||$==="ref"&&b.ref===void 0||(E[$]=b[$]);var $=arguments.length-2;if($===1)E.children=k;else if(1<$){for(var M=Array($),Q=0;Q<$;Q++)M[Q]=arguments[Q+2];E.children=M}return K(a.type,_,E)},e.createContext=function(a){return a={$$typeof:g,_currentValue:a,_currentValue2:a,_threadCount:0,Provider:null,Consumer:null},a.Provider=a,a.Consumer={$$typeof:l,_context:a},a},e.createElement=function(a,b,k){var E,_={},$=null;if(b!=null)for(E in b.key!==void 0&&($=""+b.key),b)U.call(b,E)&&E!=="key"&&E!=="__self"&&E!=="__source"&&(_[E]=b[E]);var M=arguments.length-2;if(M===1)_.children=k;else if(1<M){for(var Q=Array(M),V=0;V<M;V++)Q[V]=arguments[V+2];_.children=Q}if(a&&a.defaultProps)for(E in M=a.defaultProps,M)_[E]===void 0&&(_[E]=M[E]);return K(a,$,_)},e.createRef=function(){return{current:null}},e.forwardRef=function(a){return{$$typeof:d,render:a}},e.isValidElement=F,e.lazy=function(a){return{$$typeof:h,_payload:{_status:-1,_result:a},_init:ne}},e.memo=function(a,b){return{$$typeof:c,type:a,compare:b===void 0?null:b}},e.startTransition=function(a){var b=C.T,k={};C.T=k;try{var E=a(),_=C.S;_!==null&&_(k,E),typeof E=="object"&&E!==null&&typeof E.then=="function"&&E.then(A,se)}catch($){se($)}finally{b!==null&&k.types!==null&&(b.types=k.types),C.T=b}},e.unstable_useCacheRefresh=function(){return C.H.useCacheRefresh()},e.use=function(a){return C.H.use(a)},e.useActionState=function(a,b,k){return C.H.useActionState(a,b,k)},e.useCallback=function(a,b){return C.H.useCallback(a,b)},e.useContext=function(a){return C.H.useContext(a)},e.useDebugValue=function(){},e.useDeferredValue=function(a,b){return C.H.useDeferredValue(a,b)},e.useEffect=function(a,b){return C.H.useEffect(a,b)},e.useEffectEvent=function(a){return C.H.useEffectEvent(a)},e.useId=function(){return C.H.useId()},e.useImperativeHandle=function(a,b,k){return C.H.useImperativeHandle(a,b,k)},e.useInsertionEffect=function(a,b){return C.H.useInsertionEffect(a,b)},e.useLayoutEffect=function(a,b){return C.H.useLayoutEffect(a,b)},e.useMemo=function(a,b){return C.H.useMemo(a,b)},e.useOptimistic=function(a,b){return C.H.useOptimistic(a,b)},e.useReducer=function(a,b,k){return C.H.useReducer(a,b,k)},e.useRef=function(a){return C.H.useRef(a)},e.useState=function(a){return C.H.useState(a)},e.useSyncExternalStore=function(a,b,k){return C.H.useSyncExternalStore(a,b,k)},e.useTransition=function(){return C.H.useTransition()},e.version="19.2.3"})),jt=ae(((e,t)=>{process.env.NODE_ENV!=="production"&&(function(){function n(r,m){Object.defineProperty(s.prototype,r,{get:function(){console.warn("%s(...) is deprecated in plain JavaScript React classes. %s",m[0],m[1])}})}function o(r){return r===null||typeof r!="object"?null:(r=wt&&r[wt]||r["@@iterator"],typeof r=="function"?r:null)}function i(r,m){r=(r=r.constructor)&&(r.displayName||r.name)||"ReactClass";var x=r+"."+m;xt[x]||(console.error("Can't call %s on a component that is not yet mounted. This is a no-op, but it might indicate a bug in your application. Instead, assign to `this.state` directly or define a `state = {};` class property with the desired state in the %s component.",m,r),xt[x]=!0)}function s(r,m,x){this.props=r,this.context=m,this.refs=ze,this.updater=x||Tt}function l(){}function g(r,m,x){this.props=r,this.context=m,this.refs=ze,this.updater=x||Tt}function d(){}function u(r){return""+r}function c(r){try{u(r);var m=!1}catch(O){m=!0}if(m){m=console;var x=m.error,S=typeof Symbol=="function"&&Symbol.toStringTag&&r[Symbol.toStringTag]||r.constructor.name||"Object";return x.call(m,"The provided key is an unsupported type %s. This value must be coerced to a string before using it here.",S),u(r)}}function h(r){if(r==null)return null;if(typeof r=="function")return r.$$typeof===nr?null:r.displayName||r.name||null;if(typeof r=="string")return r;switch(r){case re:return"Fragment";case b:return"Profiler";case a:return"StrictMode";case $:return"Suspense";case M:return"SuspenseList";case he:return"Activity"}if(typeof r=="object")switch(typeof r.tag=="number"&&console.error("Received an unexpected object in getComponentNameFromType(). This is likely a bug in React. Please file an issue."),r.$$typeof){case se:return"Portal";case E:return r.displayName||"Context";case k:return(r._context.displayName||"Context")+".Consumer";case _:var m=r.render;return r=r.displayName,r||(r=m.displayName||m.name||"",r=r!==""?"ForwardRef("+r+")":"ForwardRef"),r;case Q:return m=r.displayName||null,m!==null?m:h(r.type)||"Memo";case V:m=r._payload,r=r._init;try{return h(r(m))}catch(x){}}return null}function p(r){if(r===re)return"<>";if(typeof r=="object"&&r!==null&&r.$$typeof===V)return"<...>";try{var m=h(r);return m?"<"+m+">":"<...>"}catch(x){return"<...>"}}function f(){var r=z.A;return r===null?null:r.getOwner()}function v(){return Error("react-stack-top-frame")}function w(r){if(_e.call(r,"key")){var m=Object.getOwnPropertyDescriptor(r,"key").get;if(m&&m.isReactWarning)return!1}return r.key!==void 0}function D(r,m){function x(){_t||(_t=!0,console.error("%s: `key` is not a prop. Trying to access it will result in `undefined` being returned. If you need to access the same value within the child component, you should pass it as a different prop. (https://react.dev/link/special-props)",m))}x.isReactWarning=!0,Object.defineProperty(r,"key",{get:x,configurable:!0})}function T(){var r=h(this.type);return Rt[r]||(Rt[r]=!0,console.error("Accessing element.ref was removed in React 19. ref is now a regular prop. It will be removed from the JSX Element type in a future release.")),r=this.props.ref,r!==void 0?r:null}function H(r,m,x,S,O,j){var N=x.ref;return r={$$typeof:ne,type:r,key:m,props:x,_owner:S},(N!==void 0?N:null)!==null?Object.defineProperty(r,"ref",{enumerable:!1,get:T}):Object.defineProperty(r,"ref",{enumerable:!1,value:null}),r._store={},Object.defineProperty(r._store,"validated",{configurable:!1,enumerable:!1,writable:!0,value:0}),Object.defineProperty(r,"_debugInfo",{configurable:!1,enumerable:!1,writable:!0,value:null}),Object.defineProperty(r,"_debugStack",{configurable:!1,enumerable:!1,writable:!0,value:O}),Object.defineProperty(r,"_debugTask",{configurable:!1,enumerable:!1,writable:!0,value:j}),Object.freeze&&(Object.freeze(r.props),Object.freeze(r)),r}function I(r,m){return m=H(r.type,m,r.props,r._owner,r._debugStack,r._debugTask),r._store&&(m._store.validated=r._store.validated),m}function B(r){y(r)?r._store&&(r._store.validated=1):typeof r=="object"&&r!==null&&r.$$typeof===V&&(r._payload.status==="fulfilled"?y(r._payload.value)&&r._payload.value._store&&(r._payload.value._store.validated=1):r._store&&(r._store.validated=1))}function y(r){return typeof r=="object"&&r!==null&&r.$$typeof===ne}function L(r){var m={"=":"=0",":":"=2"};return"$"+r.replace(/[=:]/g,function(x){return m[x]})}function A(r,m){return typeof r=="object"&&r!==null&&r.key!=null?(c(r.key),L(""+r.key)):m.toString(36)}function C(r){switch(r.status){case"fulfilled":return r.value;case"rejected":throw r.reason;default:switch(typeof r.status=="string"?r.then(d,d):(r.status="pending",r.then(function(m){r.status==="pending"&&(r.status="fulfilled",r.value=m)},function(m){r.status==="pending"&&(r.status="rejected",r.reason=m)})),r.status){case"fulfilled":return r.value;case"rejected":throw r.reason}}throw r}function U(r,m,x,S,O){var j=typeof r;(j==="undefined"||j==="boolean")&&(r=null);var N=!1;if(r===null)N=!0;else switch(j){case"bigint":case"string":case"number":N=!0;break;case"object":switch(r.$$typeof){case ne:case se:N=!0;break;case V:return N=r._init,U(N(r._payload),m,x,S,O)}}if(N){N=r,O=O(N);var X=S===""?"."+A(N,0):S;return Et(O)?(x="",X!=null&&(x=X.replace(Ot,"$&/")+"/"),U(O,m,x,"",function(de){return de})):O!=null&&(y(O)&&(O.key!=null&&(N&&N.key===O.key||c(O.key)),x=I(O,x+(O.key==null||N&&N.key===O.key?"":(""+O.key).replace(Ot,"$&/")+"/")+X),S!==""&&N!=null&&y(N)&&N.key==null&&N._store&&!N._store.validated&&(x._store.validated=2),O=x),m.push(O)),1}if(N=0,X=S===""?".":S+":",Et(r))for(var W=0;W<r.length;W++)S=r[W],j=X+A(S,W),N+=U(S,m,x,j,O);else if(W=o(r),typeof W=="function")for(W===r.entries&&(Dt||console.warn("Using Maps as children is not supported. Use an array of keyed ReactElements instead."),Dt=!0),r=W.call(r),W=0;!(S=r.next()).done;)S=S.value,j=X+A(S,W++),N+=U(S,m,x,j,O);else if(j==="object"){if(typeof r.then=="function")return U(C(r),m,x,S,O);throw m=String(r),Error("Objects are not valid as a React child (found: "+(m==="[object Object]"?"object with keys {"+Object.keys(r).join(", ")+"}":m)+"). If you meant to render a collection of children, use an array instead.")}return N}function K(r,m,x){if(r==null)return r;var S=[],O=0;return U(r,S,"","",function(j){return m.call(x,j,O++)}),S}function J(r){if(r._status===-1){var m=r._ioInfo;m!=null&&(m.start=m.end=performance.now()),m=r._result;var x=m();if(x.then(function(O){if(r._status===0||r._status===-1){r._status=1,r._result=O;var j=r._ioInfo;j!=null&&(j.end=performance.now()),x.status===void 0&&(x.status="fulfilled",x.value=O)}},function(O){if(r._status===0||r._status===-1){r._status=2,r._result=O;var j=r._ioInfo;j!=null&&(j.end=performance.now()),x.status===void 0&&(x.status="rejected",x.reason=O)}}),m=r._ioInfo,m!=null){m.value=x;var S=x.displayName;typeof S=="string"&&(m.name=S)}r._status===-1&&(r._status=0,r._result=x)}if(r._status===1)return m=r._result,m===void 0&&console.error(`lazy: Expected the result of a dynamic import() call. Instead received: %s

Your code should look like: 
  const MyComponent = lazy(() => import('./MyComponent'))

Did you accidentally put curly braces around the import?`,m),"default"in m||console.error(`lazy: Expected the result of a dynamic import() call. Instead received: %s

Your code should look like: 
  const MyComponent = lazy(() => import('./MyComponent'))`,m),m.default;throw r._result}function F(){var r=z.H;return r===null&&console.error(`Invalid hook call. Hooks can only be called inside of the body of a function component. This could happen for one of the following reasons:
1. You might have mismatching versions of React and the renderer (such as React DOM)
2. You might be breaking the Rules of Hooks
3. You might have more than one copy of React in the same app
See https://react.dev/link/invalid-hook-call for tips about how to debug and fix this problem.`),r}function ie(){z.asyncTransitions--}function ee(r){if(Ce===null)try{var m=("require"+Math.random()).slice(0,7);Ce=(t&&t[m]).call(t,"timers").setImmediate}catch(x){Ce=function(S){Mt===!1&&(Mt=!0,typeof MessageChannel=="undefined"&&console.error("This browser does not have a MessageChannel implementation, so enqueuing tasks via await act(async () => ...) will fail. Please file an issue at https://github.com/facebook/react/issues if you encounter this warning."));var O=new MessageChannel;O.port1.onmessage=S,O.port2.postMessage(void 0)}}return Ce(r)}function te(r){return 1<r.length&&typeof AggregateError=="function"?new AggregateError(r):r[0]}function q(r,m){m!==Re-1&&console.error("You seem to have overlapping act() calls, this is not supported. Be sure to await previous act() calls before making a new one. "),Re=m}function G(r,m,x){var S=z.actQueue;if(S!==null)if(S.length!==0)try{Z(S),ee(function(){return G(r,m,x)});return}catch(O){z.thrownErrors.push(O)}else z.actQueue=null;0<z.thrownErrors.length?(S=te(z.thrownErrors),z.thrownErrors.length=0,x(S)):m(r)}function Z(r){if(!je){je=!0;var m=0;try{for(;m<r.length;m++){var x=r[m];do{z.didUsePromise=!1;var S=x(!1);if(S!==null){if(z.didUsePromise){r[m]=x,r.splice(0,m);return}x=S}else break}while(!0)}r.length=0}catch(O){r.splice(0,m+1),z.thrownErrors.push(O)}finally{je=!1}}}typeof __REACT_DEVTOOLS_GLOBAL_HOOK__!="undefined"&&typeof __REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStart=="function"&&__REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStart(Error());var ne=Symbol.for("react.transitional.element"),se=Symbol.for("react.portal"),re=Symbol.for("react.fragment"),a=Symbol.for("react.strict_mode"),b=Symbol.for("react.profiler"),k=Symbol.for("react.consumer"),E=Symbol.for("react.context"),_=Symbol.for("react.forward_ref"),$=Symbol.for("react.suspense"),M=Symbol.for("react.suspense_list"),Q=Symbol.for("react.memo"),V=Symbol.for("react.lazy"),he=Symbol.for("react.activity"),wt=Symbol.iterator,xt={},Tt={isMounted:function(){return!1},enqueueForceUpdate:function(r){i(r,"forceUpdate")},enqueueReplaceState:function(r){i(r,"replaceState")},enqueueSetState:function(r){i(r,"setState")}},kt=Object.assign,ze={};Object.freeze(ze),s.prototype.isReactComponent={},s.prototype.setState=function(r,m){if(typeof r!="object"&&typeof r!="function"&&r!=null)throw Error("takes an object of state variables to update or a function which returns an object of state variables.");this.updater.enqueueSetState(this,r,m,"setState")},s.prototype.forceUpdate=function(r){this.updater.enqueueForceUpdate(this,r,"forceUpdate")};var oe={isMounted:["isMounted","Instead, make sure to clean up subscriptions and pending requests in componentWillUnmount to prevent memory leaks."],replaceState:["replaceState","Refactor your code to use setState instead (see https://github.com/facebook/react/issues/3236)."]};for(we in oe)oe.hasOwnProperty(we)&&n(we,oe[we]);l.prototype=s.prototype,oe=g.prototype=new l,oe.constructor=g,kt(oe,s.prototype),oe.isPureReactComponent=!0;var Et=Array.isArray,nr=Symbol.for("react.client.reference"),z={H:null,A:null,T:null,S:null,actQueue:null,asyncTransitions:0,isBatchingLegacy:!1,didScheduleLegacyUpdate:!1,didUsePromise:!1,thrownErrors:[],getCurrentStack:null,recentlyCreatedOwnerStacks:0},_e=Object.prototype.hasOwnProperty,St=console.createTask?console.createTask:function(){return null};oe={react_stack_bottom_frame:function(r){return r()}};var _t,Ct,Rt={},rr=oe.react_stack_bottom_frame.bind(oe,v)(),or=St(p(v)),Dt=!1,Ot=/\/+/g,It=typeof reportError=="function"?reportError:function(r){if(typeof window=="object"&&typeof window.ErrorEvent=="function"){var m=new window.ErrorEvent("error",{bubbles:!0,cancelable:!0,message:typeof r=="object"&&r!==null&&typeof r.message=="string"?String(r.message):String(r),error:r});if(!window.dispatchEvent(m))return}else if(typeof process=="object"&&typeof process.emit=="function"){process.emit("uncaughtException",r);return}console.error(r)},Mt=!1,Ce=null,Re=0,De=!1,je=!1,Pt=typeof queueMicrotask=="function"?function(r){queueMicrotask(function(){return queueMicrotask(r)})}:ee;oe=Object.freeze({__proto__:null,c:function(r){return F().useMemoCache(r)}});var we={map:K,forEach:function(r,m,x){K(r,function(){m.apply(this,arguments)},x)},count:function(r){var m=0;return K(r,function(){m++}),m},toArray:function(r){return K(r,function(m){return m})||[]},only:function(r){if(!y(r))throw Error("React.Children.only expected to receive a single React element child.");return r}};e.Activity=he,e.Children=we,e.Component=s,e.Fragment=re,e.Profiler=b,e.PureComponent=g,e.StrictMode=a,e.Suspense=$,e.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE=z,e.__COMPILER_RUNTIME=oe,e.act=function(r){var m=z.actQueue,x=Re;Re++;var S=z.actQueue=m!==null?m:[],O=!1;try{var j=r()}catch(W){z.thrownErrors.push(W)}if(0<z.thrownErrors.length)throw q(m,x),r=te(z.thrownErrors),z.thrownErrors.length=0,r;if(j!==null&&typeof j=="object"&&typeof j.then=="function"){var N=j;return Pt(function(){O||De||(De=!0,console.error("You called act(async () => ...) without await. This could lead to unexpected testing behaviour, interleaving multiple act calls and mixing their scopes. You should - await act(async () => ...);"))}),{then:function(W,de){O=!0,N.then(function(pe){if(q(m,x),x===0){try{Z(S),ee(function(){return G(pe,W,de)})}catch(sr){z.thrownErrors.push(sr)}if(0<z.thrownErrors.length){var ir=te(z.thrownErrors);z.thrownErrors.length=0,de(ir)}}else W(pe)},function(pe){q(m,x),0<z.thrownErrors.length&&(pe=te(z.thrownErrors),z.thrownErrors.length=0),de(pe)})}}}var X=j;if(q(m,x),x===0&&(Z(S),S.length!==0&&Pt(function(){O||De||(De=!0,console.error("A component suspended inside an `act` scope, but the `act` call was not awaited. When testing React components that depend on asynchronous data, you must await the result:\n\nawait act(() => ...)"))}),z.actQueue=null),0<z.thrownErrors.length)throw r=te(z.thrownErrors),z.thrownErrors.length=0,r;return{then:function(W,de){O=!0,x===0?(z.actQueue=S,ee(function(){return G(X,W,de)})):W(X)}}},e.cache=function(r){return function(){return r.apply(null,arguments)}},e.cacheSignal=function(){return null},e.captureOwnerStack=function(){var r=z.getCurrentStack;return r===null?null:r()},e.cloneElement=function(r,m,x){if(r==null)throw Error("The argument must be a React element, but you passed "+r+".");var S=kt({},r.props),O=r.key,j=r._owner;if(m!=null){var N;e:{if(_e.call(m,"ref")&&(N=Object.getOwnPropertyDescriptor(m,"ref").get)&&N.isReactWarning){N=!1;break e}N=m.ref!==void 0}N&&(j=f()),w(m)&&(c(m.key),O=""+m.key);for(X in m)!_e.call(m,X)||X==="key"||X==="__self"||X==="__source"||X==="ref"&&m.ref===void 0||(S[X]=m[X])}var X=arguments.length-2;if(X===1)S.children=x;else if(1<X){N=Array(X);for(var W=0;W<X;W++)N[W]=arguments[W+2];S.children=N}for(S=H(r.type,O,S,j,r._debugStack,r._debugTask),O=2;O<arguments.length;O++)B(arguments[O]);return S},e.createContext=function(r){return r={$$typeof:E,_currentValue:r,_currentValue2:r,_threadCount:0,Provider:null,Consumer:null},r.Provider=r,r.Consumer={$$typeof:k,_context:r},r._currentRenderer=null,r._currentRenderer2=null,r},e.createElement=function(r,m,x){for(var S=2;S<arguments.length;S++)B(arguments[S]);S={};var O=null;if(m!=null)for(W in Ct||!("__self"in m)||"key"in m||(Ct=!0,console.warn("Your app (or one of its dependencies) is using an outdated JSX transform. Update to the modern JSX transform for faster performance: https://react.dev/link/new-jsx-transform")),w(m)&&(c(m.key),O=""+m.key),m)_e.call(m,W)&&W!=="key"&&W!=="__self"&&W!=="__source"&&(S[W]=m[W]);var j=arguments.length-2;if(j===1)S.children=x;else if(1<j){for(var N=Array(j),X=0;X<j;X++)N[X]=arguments[X+2];Object.freeze&&Object.freeze(N),S.children=N}if(r&&r.defaultProps)for(W in j=r.defaultProps,j)S[W]===void 0&&(S[W]=j[W]);O&&D(S,typeof r=="function"?r.displayName||r.name||"Unknown":r);var W=1e4>z.recentlyCreatedOwnerStacks++;return H(r,O,S,f(),W?Error("react-stack-top-frame"):rr,W?St(p(r)):or)},e.createRef=function(){var r={current:null};return Object.seal(r),r},e.forwardRef=function(r){r!=null&&r.$$typeof===Q?console.error("forwardRef requires a render function but received a `memo` component. Instead of forwardRef(memo(...)), use memo(forwardRef(...))."):typeof r!="function"?console.error("forwardRef requires a render function but was given %s.",r===null?"null":typeof r):r.length!==0&&r.length!==2&&console.error("forwardRef render functions accept exactly two parameters: props and ref. %s",r.length===1?"Did you forget to use the ref parameter?":"Any additional parameter will be undefined."),r!=null&&r.defaultProps!=null&&console.error("forwardRef render functions do not support defaultProps. Did you accidentally pass a React component?");var m={$$typeof:_,render:r},x;return Object.defineProperty(m,"displayName",{enumerable:!1,configurable:!0,get:function(){return x},set:function(S){x=S,r.name||r.displayName||(Object.defineProperty(r,"name",{value:S}),r.displayName=S)}}),m},e.isValidElement=y,e.lazy=function(r){r={_status:-1,_result:r};var m={$$typeof:V,_payload:r,_init:J},x={name:"lazy",start:-1,end:-1,value:null,owner:null,debugStack:Error("react-stack-top-frame"),debugTask:console.createTask?console.createTask("lazy()"):null};return r._ioInfo=x,m._debugInfo=[{awaited:x}],m},e.memo=function(r,m){r==null&&console.error("memo: The first argument must be a component. Instead received: %s",r===null?"null":typeof r),m={$$typeof:Q,type:r,compare:m===void 0?null:m};var x;return Object.defineProperty(m,"displayName",{enumerable:!1,configurable:!0,get:function(){return x},set:function(S){x=S,r.name||r.displayName||(Object.defineProperty(r,"name",{value:S}),r.displayName=S)}}),m},e.startTransition=function(r){var m=z.T,x={};x._updatedFibers=new Set,z.T=x;try{var S=r(),O=z.S;O!==null&&O(x,S),typeof S=="object"&&S!==null&&typeof S.then=="function"&&(z.asyncTransitions++,S.then(ie,ie),S.then(d,It))}catch(j){It(j)}finally{m===null&&x._updatedFibers&&(r=x._updatedFibers.size,x._updatedFibers.clear(),10<r&&console.warn("Detected a large number of updates inside startTransition. If this is due to a subscription please re-write it to use React provided hooks. Otherwise concurrent mode guarantees are off the table.")),m!==null&&x.types!==null&&(m.types!==null&&m.types!==x.types&&console.error("We expected inner Transitions to have transferred the outer types set and that you cannot add to the outer Transition while inside the inner.This is a bug in React."),m.types=x.types),z.T=m}},e.unstable_useCacheRefresh=function(){return F().useCacheRefresh()},e.use=function(r){return F().use(r)},e.useActionState=function(r,m,x){return F().useActionState(r,m,x)},e.useCallback=function(r,m){return F().useCallback(r,m)},e.useContext=function(r){var m=F();return r.$$typeof===k&&console.error("Calling useContext(Context.Consumer) is not supported and will cause bugs. Did you mean to call useContext(Context) instead?"),m.useContext(r)},e.useDebugValue=function(r,m){return F().useDebugValue(r,m)},e.useDeferredValue=function(r,m){return F().useDeferredValue(r,m)},e.useEffect=function(r,m){return r==null&&console.warn("React Hook useEffect requires an effect callback. Did you forget to pass a callback to the hook?"),F().useEffect(r,m)},e.useEffectEvent=function(r){return F().useEffectEvent(r)},e.useId=function(){return F().useId()},e.useImperativeHandle=function(r,m,x){return F().useImperativeHandle(r,m,x)},e.useInsertionEffect=function(r,m){return r==null&&console.warn("React Hook useInsertionEffect requires an effect callback. Did you forget to pass a callback to the hook?"),F().useInsertionEffect(r,m)},e.useLayoutEffect=function(r,m){return r==null&&console.warn("React Hook useLayoutEffect requires an effect callback. Did you forget to pass a callback to the hook?"),F().useLayoutEffect(r,m)},e.useMemo=function(r,m){return F().useMemo(r,m)},e.useOptimistic=function(r,m){return F().useOptimistic(r,m)},e.useReducer=function(r,m,x){return F().useReducer(r,m,x)},e.useRef=function(r){return F().useRef(r)},e.useState=function(r){return F().useState(r)},e.useSyncExternalStore=function(r,m,x){return F().useSyncExternalStore(r,m,x)},e.useTransition=function(){return F().useTransition()},e.version="19.2.3",typeof __REACT_DEVTOOLS_GLOBAL_HOOK__!="undefined"&&typeof __REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStop=="function"&&__REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStop(Error())})()})),xe=ae(((e,t)=>{process.env.NODE_ENV==="production"?t.exports=zt():t.exports=jt()})),Wt=ae((e=>{var t=xe();function n(u){var c="https://react.dev/errors/"+u;if(1<arguments.length){c+="?args[]="+encodeURIComponent(arguments[1]);for(var h=2;h<arguments.length;h++)c+="&args[]="+encodeURIComponent(arguments[h])}return"Minified React error #"+u+"; visit "+c+" for the full message or use the non-minified dev environment for full errors and additional helpful warnings."}function o(){}var i={d:{f:o,r:function(){throw Error(n(522))},D:o,C:o,L:o,m:o,X:o,S:o,M:o},p:0,findDOMNode:null},s=Symbol.for("react.portal");function l(u,c,h){var p=3<arguments.length&&arguments[3]!==void 0?arguments[3]:null;return{$$typeof:s,key:p==null?null:""+p,children:u,containerInfo:c,implementation:h}}var g=t.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE;function d(u,c){if(u==="font")return"";if(typeof c=="string")return c==="use-credentials"?c:""}e.__DOM_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE=i,e.createPortal=function(u,c){var h=2<arguments.length&&arguments[2]!==void 0?arguments[2]:null;if(!c||c.nodeType!==1&&c.nodeType!==9&&c.nodeType!==11)throw Error(n(299));return l(u,c,null,h)},e.flushSync=function(u){var c=g.T,h=i.p;try{if(g.T=null,i.p=2,u)return u()}finally{g.T=c,i.p=h,i.d.f()}},e.preconnect=function(u,c){typeof u=="string"&&(c?(c=c.crossOrigin,c=typeof c=="string"?c==="use-credentials"?c:"":void 0):c=null,i.d.C(u,c))},e.prefetchDNS=function(u){typeof u=="string"&&i.d.D(u)},e.preinit=function(u,c){if(typeof u=="string"&&c&&typeof c.as=="string"){var h=c.as,p=d(h,c.crossOrigin),f=typeof c.integrity=="string"?c.integrity:void 0,v=typeof c.fetchPriority=="string"?c.fetchPriority:void 0;h==="style"?i.d.S(u,typeof c.precedence=="string"?c.precedence:void 0,{crossOrigin:p,integrity:f,fetchPriority:v}):h==="script"&&i.d.X(u,{crossOrigin:p,integrity:f,fetchPriority:v,nonce:typeof c.nonce=="string"?c.nonce:void 0})}},e.preinitModule=function(u,c){if(typeof u=="string")if(typeof c=="object"&&c!==null){if(c.as==null||c.as==="script"){var h=d(c.as,c.crossOrigin);i.d.M(u,{crossOrigin:h,integrity:typeof c.integrity=="string"?c.integrity:void 0,nonce:typeof c.nonce=="string"?c.nonce:void 0})}}else c==null&&i.d.M(u)},e.preload=function(u,c){if(typeof u=="string"&&typeof c=="object"&&c!==null&&typeof c.as=="string"){var h=c.as,p=d(h,c.crossOrigin);i.d.L(u,h,{crossOrigin:p,integrity:typeof c.integrity=="string"?c.integrity:void 0,nonce:typeof c.nonce=="string"?c.nonce:void 0,type:typeof c.type=="string"?c.type:void 0,fetchPriority:typeof c.fetchPriority=="string"?c.fetchPriority:void 0,referrerPolicy:typeof c.referrerPolicy=="string"?c.referrerPolicy:void 0,imageSrcSet:typeof c.imageSrcSet=="string"?c.imageSrcSet:void 0,imageSizes:typeof c.imageSizes=="string"?c.imageSizes:void 0,media:typeof c.media=="string"?c.media:void 0})}},e.preloadModule=function(u,c){if(typeof u=="string")if(c){var h=d(c.as,c.crossOrigin);i.d.m(u,{as:typeof c.as=="string"&&c.as!=="script"?c.as:void 0,crossOrigin:h,integrity:typeof c.integrity=="string"?c.integrity:void 0})}else i.d.m(u)},e.requestFormReset=function(u){i.d.r(u)},e.unstable_batchedUpdates=function(u,c){return u(c)},e.useFormState=function(u,c,h){return g.H.useFormState(u,c,h)},e.useFormStatus=function(){return g.H.useHostTransitionStatus()},e.version="19.2.3"})),Yt=ae((e=>{process.env.NODE_ENV!=="production"&&(function(){function t(){}function n(p){return""+p}function o(p,f,v){var w=3<arguments.length&&arguments[3]!==void 0?arguments[3]:null;try{n(w);var D=!1}catch(T){D=!0}return D&&(console.error("The provided key is an unsupported type %s. This value must be coerced to a string before using it here.",typeof Symbol=="function"&&Symbol.toStringTag&&w[Symbol.toStringTag]||w.constructor.name||"Object"),n(w)),{$$typeof:c,key:w==null?null:""+w,children:p,containerInfo:f,implementation:v}}function i(p,f){if(p==="font")return"";if(typeof f=="string")return f==="use-credentials"?f:""}function s(p){return p===null?"`null`":p===void 0?"`undefined`":p===""?"an empty string":'something with type "'+typeof p+'"'}function l(p){return p===null?"`null`":p===void 0?"`undefined`":p===""?"an empty string":typeof p=="string"?JSON.stringify(p):typeof p=="number"?"`"+p+"`":'something with type "'+typeof p+'"'}function g(){var p=h.H;return p===null&&console.error(`Invalid hook call. Hooks can only be called inside of the body of a function component. This could happen for one of the following reasons:
1. You might have mismatching versions of React and the renderer (such as React DOM)
2. You might be breaking the Rules of Hooks
3. You might have more than one copy of React in the same app
See https://react.dev/link/invalid-hook-call for tips about how to debug and fix this problem.`),p}typeof __REACT_DEVTOOLS_GLOBAL_HOOK__!="undefined"&&typeof __REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStart=="function"&&__REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStart(Error());var d=xe(),u={d:{f:t,r:function(){throw Error("Invalid form element. requestFormReset must be passed a form that was rendered by React.")},D:t,C:t,L:t,m:t,X:t,S:t,M:t},p:0,findDOMNode:null},c=Symbol.for("react.portal"),h=d.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE;typeof Map=="function"&&Map.prototype!=null&&typeof Map.prototype.forEach=="function"&&typeof Set=="function"&&Set.prototype!=null&&typeof Set.prototype.clear=="function"&&typeof Set.prototype.forEach=="function"||console.error("React depends on Map and Set built-in types. Make sure that you load a polyfill in older browsers. https://reactjs.org/link/react-polyfills"),e.__DOM_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE=u,e.createPortal=function(p,f){var v=2<arguments.length&&arguments[2]!==void 0?arguments[2]:null;if(!f||f.nodeType!==1&&f.nodeType!==9&&f.nodeType!==11)throw Error("Target container is not a DOM element.");return o(p,f,null,v)},e.flushSync=function(p){var f=h.T,v=u.p;try{if(h.T=null,u.p=2,p)return p()}finally{h.T=f,u.p=v,u.d.f()&&console.error("flushSync was called from inside a lifecycle method. React cannot flush when React is already rendering. Consider moving this call to a scheduler task or micro task.")}},e.preconnect=function(p,f){typeof p=="string"&&p?f!=null&&typeof f!="object"?console.error("ReactDOM.preconnect(): Expected the `options` argument (second) to be an object but encountered %s instead. The only supported option at this time is `crossOrigin` which accepts a string.",l(f)):f!=null&&typeof f.crossOrigin!="string"&&console.error("ReactDOM.preconnect(): Expected the `crossOrigin` option (second argument) to be a string but encountered %s instead. Try removing this option or passing a string value instead.",s(f.crossOrigin)):console.error("ReactDOM.preconnect(): Expected the `href` argument (first) to be a non-empty string but encountered %s instead.",s(p)),typeof p=="string"&&(f?(f=f.crossOrigin,f=typeof f=="string"?f==="use-credentials"?f:"":void 0):f=null,u.d.C(p,f))},e.prefetchDNS=function(p){if(typeof p!="string"||!p)console.error("ReactDOM.prefetchDNS(): Expected the `href` argument (first) to be a non-empty string but encountered %s instead.",s(p));else if(1<arguments.length){var f=arguments[1];typeof f=="object"&&f.hasOwnProperty("crossOrigin")?console.error("ReactDOM.prefetchDNS(): Expected only one argument, `href`, but encountered %s as a second argument instead. This argument is reserved for future options and is currently disallowed. It looks like the you are attempting to set a crossOrigin property for this DNS lookup hint. Browsers do not perform DNS queries using CORS and setting this attribute on the resource hint has no effect. Try calling ReactDOM.prefetchDNS() with just a single string argument, `href`.",l(f)):console.error("ReactDOM.prefetchDNS(): Expected only one argument, `href`, but encountered %s as a second argument instead. This argument is reserved for future options and is currently disallowed. Try calling ReactDOM.prefetchDNS() with just a single string argument, `href`.",l(f))}typeof p=="string"&&u.d.D(p)},e.preinit=function(p,f){if(typeof p=="string"&&p?f==null||typeof f!="object"?console.error("ReactDOM.preinit(): Expected the `options` argument (second) to be an object with an `as` property describing the type of resource to be preinitialized but encountered %s instead.",l(f)):f.as!=="style"&&f.as!=="script"&&console.error('ReactDOM.preinit(): Expected the `as` property in the `options` argument (second) to contain a valid value describing the type of resource to be preinitialized but encountered %s instead. Valid values for `as` are "style" and "script".',l(f.as)):console.error("ReactDOM.preinit(): Expected the `href` argument (first) to be a non-empty string but encountered %s instead.",s(p)),typeof p=="string"&&f&&typeof f.as=="string"){var v=f.as,w=i(v,f.crossOrigin),D=typeof f.integrity=="string"?f.integrity:void 0,T=typeof f.fetchPriority=="string"?f.fetchPriority:void 0;v==="style"?u.d.S(p,typeof f.precedence=="string"?f.precedence:void 0,{crossOrigin:w,integrity:D,fetchPriority:T}):v==="script"&&u.d.X(p,{crossOrigin:w,integrity:D,fetchPriority:T,nonce:typeof f.nonce=="string"?f.nonce:void 0})}},e.preinitModule=function(p,f){var v="";if(typeof p=="string"&&p||(v+=" The `href` argument encountered was "+s(p)+"."),f!==void 0&&typeof f!="object"?v+=" The `options` argument encountered was "+s(f)+".":f&&"as"in f&&f.as!=="script"&&(v+=" The `as` option encountered was "+l(f.as)+"."),v)console.error("ReactDOM.preinitModule(): Expected up to two arguments, a non-empty `href` string and, optionally, an `options` object with a valid `as` property.%s",v);else switch(v=f&&typeof f.as=="string"?f.as:"script",v){case"script":break;default:v=l(v),console.error('ReactDOM.preinitModule(): Currently the only supported "as" type for this function is "script" but received "%s" instead. This warning was generated for `href` "%s". In the future other module types will be supported, aligning with the import-attributes proposal. Learn more here: (https://github.com/tc39/proposal-import-attributes)',v,p)}typeof p=="string"&&(typeof f=="object"&&f!==null?(f.as==null||f.as==="script")&&(v=i(f.as,f.crossOrigin),u.d.M(p,{crossOrigin:v,integrity:typeof f.integrity=="string"?f.integrity:void 0,nonce:typeof f.nonce=="string"?f.nonce:void 0})):f==null&&u.d.M(p))},e.preload=function(p,f){var v="";if(typeof p=="string"&&p||(v+=" The `href` argument encountered was "+s(p)+"."),f==null||typeof f!="object"?v+=" The `options` argument encountered was "+s(f)+".":typeof f.as=="string"&&f.as||(v+=" The `as` option encountered was "+s(f.as)+"."),v&&console.error('ReactDOM.preload(): Expected two arguments, a non-empty `href` string and an `options` object with an `as` property valid for a `<link rel="preload" as="..." />` tag.%s',v),typeof p=="string"&&typeof f=="object"&&f!==null&&typeof f.as=="string"){v=f.as;var w=i(v,f.crossOrigin);u.d.L(p,v,{crossOrigin:w,integrity:typeof f.integrity=="string"?f.integrity:void 0,nonce:typeof f.nonce=="string"?f.nonce:void 0,type:typeof f.type=="string"?f.type:void 0,fetchPriority:typeof f.fetchPriority=="string"?f.fetchPriority:void 0,referrerPolicy:typeof f.referrerPolicy=="string"?f.referrerPolicy:void 0,imageSrcSet:typeof f.imageSrcSet=="string"?f.imageSrcSet:void 0,imageSizes:typeof f.imageSizes=="string"?f.imageSizes:void 0,media:typeof f.media=="string"?f.media:void 0})}},e.preloadModule=function(p,f){var v="";typeof p=="string"&&p||(v+=" The `href` argument encountered was "+s(p)+"."),f!==void 0&&typeof f!="object"?v+=" The `options` argument encountered was "+s(f)+".":f&&"as"in f&&typeof f.as!="string"&&(v+=" The `as` option encountered was "+s(f.as)+"."),v&&console.error('ReactDOM.preloadModule(): Expected two arguments, a non-empty `href` string and, optionally, an `options` object with an `as` property valid for a `<link rel="modulepreload" as="..." />` tag.%s',v),typeof p=="string"&&(f?(v=i(f.as,f.crossOrigin),u.d.m(p,{as:typeof f.as=="string"&&f.as!=="script"?f.as:void 0,crossOrigin:v,integrity:typeof f.integrity=="string"?f.integrity:void 0})):u.d.m(p))},e.requestFormReset=function(p){u.d.r(p)},e.unstable_batchedUpdates=function(p,f){return p(f)},e.useFormState=function(p,f,v){return g().useFormState(p,f,v)},e.useFormStatus=function(){return g().useHostTransitionStatus()},e.version="19.2.3",typeof __REACT_DEVTOOLS_GLOBAL_HOOK__!="undefined"&&typeof __REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStop=="function"&&__REACT_DEVTOOLS_GLOBAL_HOOK__.registerInternalModuleStop(Error())})()})),Ut=ae(((e,t)=>{function n(){if(!(typeof __REACT_DEVTOOLS_GLOBAL_HOOK__=="undefined"||typeof __REACT_DEVTOOLS_GLOBAL_HOOK__.checkDCE!="function")){if(process.env.NODE_ENV!=="production")throw new Error("^_^");try{__REACT_DEVTOOLS_GLOBAL_HOOK__.checkDCE(n)}catch(o){console.error(o)}}}process.env.NODE_ENV==="production"?(n(),t.exports=Wt()):t.exports=Yt()})),Y=Ye(xe()),Ue=Ye(Ut());function me(e){"@babel/helpers - typeof";return me=typeof Symbol=="function"&&typeof Symbol.iterator=="symbol"?function(t){return typeof t}:function(t){return t&&typeof Symbol=="function"&&t.constructor===Symbol&&t!==Symbol.prototype?"symbol":typeof t},me(e)}function Ft(e,t){if(me(e)!="object"||!e)return e;var n=e[Symbol.toPrimitive];if(n!==void 0){var o=n.call(e,t||"default");if(me(o)!="object")return o;throw new TypeError("@@toPrimitive must return a primitive value.")}return(t==="string"?String:Number)(e)}function Gt(e){var t=Ft(e,"string");return me(t)=="symbol"?t:t+""}function Xt(e,t,n){return(t=Gt(t))in e?Object.defineProperty(e,t,{value:n,enumerable:!0,configurable:!0,writable:!0}):e[t]=n,e}function Fe(e,t){var n=Object.keys(e);if(Object.getOwnPropertySymbols){var o=Object.getOwnPropertySymbols(e);t&&(o=o.filter(function(i){return Object.getOwnPropertyDescriptor(e,i).enumerable})),n.push.apply(n,o)}return n}function R(e){for(var t=1;t<arguments.length;t++){var n=arguments[t]!=null?arguments[t]:{};t%2?Fe(Object(n),!0).forEach(function(o){Xt(e,o,n[o])}):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(n)):Fe(Object(n)).forEach(function(o){Object.defineProperty(e,o,Object.getOwnPropertyDescriptor(n,o))})}return e}function le(e,t){const n=new Map;for(const l of e.values()){const g=l.parentId&&e.has(l.parentId)?l.parentId:void 0;let d=n.get(g);d||(d=[],n.set(g,d)),d.push(l)}const o=[];function i(l,g){var d,u;const c=(d=l.sortOrder)!==null&&d!==void 0?d:Number.MAX_SAFE_INTEGER,h=(u=g.sortOrder)!==null&&u!==void 0?u:Number.MAX_SAFE_INTEGER;return c!==h?c-h:l.name.localeCompare(g.name)}function s(l,g,d){const u=n.get(l);return u?(u.sort(i),u.map(c=>{const h=n.has(c.id)&&t.has(c.id),p=d,f={task:c,children:[],depth:g,expanded:h,visible:p,rowIndex:-1};return p&&(f.rowIndex=o.length,o.push(c.id)),f.children=s(c.id,g+1,p&&h),f})):[]}return{tree:s(void 0,0,!0),flatIds:o}}function be(e,t=7){let n=1/0,o=-1/0;for(const s of e.values()){if(s.startDate){const l=new Date(s.startDate).getTime();l<n&&(n=l)}if(s.endDate){const l=new Date(s.endDate).getTime();l>o&&(o=l)}}const i=864e5;if(n===1/0||o===-1/0){const s=new Date;return s.setHours(0,0,0,0),{start:new Date(s.getTime()-30*i),end:new Date(s.getTime()+30*i)}}return{start:new Date(n-t*i),end:new Date(o+t*i)}}var Ge=class{constructor(e,t=[]){this.listeners=new Set,this.state=e,this.middlewares=t}getState(){return this.state}subscribe(e){return this.listeners.add(e),()=>{this.listeners.delete(e)}}dispatch(e){if(this.middlewares.length===0){this.applyAction(e);return}this.middlewares.reduceRight((t,n)=>o=>n(o,()=>this.state,t),t=>this.applyAction(t))(e)}applyAction(e){const t=qt(this.state,e);t!==this.state&&(this.state=t,this.notify())}notify(){for(const e of this.listeners)e()}};function qt(e,t){switch(t.type){case"SET_DATA":{const n=new Map;for(const g of t.tasks)n.set(g.id,g);const o=new Map;if(t.dependencies)for(const g of t.dependencies)o.set(g.id,g);const{tree:i,flatIds:s}=le(n,e.expandedIds),l=be(n);return R(R({},e),{},{tasks:n,dependencies:o,tree:i,flatVisibleIds:s,dateRange:l})}case"UPDATE_TASK":{const n=e.tasks.get(t.taskId);if(!n)return e;const o=R(R({},n),t.changes),i=new Map(e.tasks);if(i.set(t.taskId,o),t.changes.parentId!==void 0&&t.changes.parentId!==n.parentId){const{tree:s,flatIds:l}=le(i,e.expandedIds);return R(R({},e),{},{tasks:i,tree:s,flatVisibleIds:l})}return R(R({},e),{},{tasks:i})}case"ADD_TASK":{const n=new Map(e.tasks);n.set(t.task.id,t.task);const{tree:o,flatIds:i}=le(n,e.expandedIds),s=be(n);return R(R({},e),{},{tasks:n,tree:o,flatVisibleIds:i,dateRange:s})}case"REMOVE_TASK":{if(!e.tasks.has(t.taskId))return e;const n=new Map(e.tasks);n.delete(t.taskId);const{tree:o,flatIds:i}=le(n,e.expandedIds),s=be(n),l=new Set(e.selectedIds);return l.delete(t.taskId),R(R({},e),{},{tasks:n,tree:o,flatVisibleIds:i,dateRange:s,selectedIds:l})}case"TOGGLE_EXPAND":{const n=new Set(e.expandedIds);n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId);const{tree:o,flatIds:i}=le(e.tasks,n);return R(R({},e),{},{expandedIds:n,tree:o,flatVisibleIds:i})}case"EXPAND_ALL":{const n=new Set,o=new Set;for(const l of e.tasks.values())l.parentId&&e.tasks.has(l.parentId)&&o.add(l.parentId);for(const l of o)n.add(l);const{tree:i,flatIds:s}=le(e.tasks,n);return R(R({},e),{},{expandedIds:n,tree:i,flatVisibleIds:s})}case"COLLAPSE_ALL":{const n=new Set,{tree:o,flatIds:i}=le(e.tasks,n);return R(R({},e),{},{expandedIds:n,tree:o,flatVisibleIds:i})}case"SET_ZOOM":return R(R({},e),{},{zoomLevel:t.level});case"SET_SCROLL":return R(R({},e),{},{scrollX:t.x,scrollY:t.y});case"SET_SCROLL_X":return R(R({},e),{},{scrollX:t.x});case"SET_SCROLL_Y":return R(R({},e),{},{scrollY:t.y});case"SELECT_TASK":{const n=t.multi?new Set(e.selectedIds):new Set;return t.multi&&n.has(t.taskId)?n.delete(t.taskId):n.add(t.taskId),R(R({},e),{},{selectedIds:n})}case"DESELECT_ALL":return R(R({},e),{},{selectedIds:new Set});case"DRAG_START":return R(R({},e),{},{dragState:t.drag});case"DRAG_UPDATE":{if(!e.dragState)return e;const n=R(R({},e.dragState),{},{currentX:t.currentX,currentY:t.currentY});return R(R({},e),{},{dragState:n})}case"DRAG_END":return R(R({},e),{},{dragState:null});case"DRAG_CANCEL":return R(R({},e),{},{dragState:null});case"TASK_MOVE":case"TASK_RESIZE":{const n=e.tasks.get(t.taskId);if(!n)return e;const o=new Map(e.tasks);o.set(t.taskId,R(R({},n),{},{startDate:t.startDate,endDate:t.endDate}));const i=be(o);return R(R({},e),{},{tasks:o,dateRange:i})}case"ADD_DEPENDENCY":{const n=new Map(e.dependencies);return n.set(t.dependency.id,t.dependency),R(R({},e),{},{dependencies:n})}case"REMOVE_DEPENDENCY":{if(!e.dependencies.has(t.dependencyId))return e;const n=new Map(e.dependencies);return n.delete(t.dependencyId),R(R({},e),{},{dependencies:n})}case"SET_DATE_RANGE":return R(R({},e),{},{dateRange:{start:t.start,end:t.end}});default:return e}}var Vt=class{constructor(){this.listeners=new Map}on(e,t){let n=this.listeners.get(e);return n||(n=new Set,this.listeners.set(e,n)),n.add(t),()=>{this.off(e,t)}}off(e,t){const n=this.listeners.get(e);n&&(n.delete(t),n.size===0&&this.listeners.delete(e))}emit(e,...t){const n=this.listeners.get(e);if(n)for(const o of[...n])o(...t)}},Oe=864e5,Kt=Oe*7,Qt={day:40,week:120,month:180,quarter:200},Xe=["January","February","March","April","May","June","July","August","September","October","November","December"],qe=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],Zt=class{constructor(e,t,n){this.zoomLevel=e,this.rangeStart=t.start,this.rangeEnd=t.end,this.viewportWidth=n,this.columnWidth=Qt[e],this.totalMs=this.rangeEnd.getTime()-this.rangeStart.getTime()}dateToX(e){const t=e.getTime()-this.rangeStart.getTime(),n=this.getTotalWidth();return t/this.totalMs*n}xToDate(e){const t=e/this.getTotalWidth()*this.totalMs;return new Date(this.rangeStart.getTime()+t)}getColumnWidth(){return this.columnWidth}getTotalWidth(){switch(this.zoomLevel){case"day":return this.countDays()*this.columnWidth;case"week":return this.countWeeks()*this.columnWidth;case"month":return this.countMonths()*this.columnWidth;case"quarter":return this.countQuarters()*this.columnWidth}}getHeaderRows(){switch(this.zoomLevel){case"day":return this.headersDay();case"week":return this.headersWeek();case"month":return this.headersMonth();case"quarter":return this.headersQuarter()}}getGridLines(){return this.getHeaderRows()[1].map(e=>e.x).filter(e=>e>0)}countDays(){return Math.round(this.totalMs/Oe)}countWeeks(){return Math.ceil(this.totalMs/Kt)}countMonths(){const e=this.rangeStart.getUTCFullYear(),t=this.rangeStart.getUTCMonth(),n=this.rangeEnd.getUTCFullYear(),o=this.rangeEnd.getUTCMonth();return(n-e)*12+(o-t)}countQuarters(){const e=this.rangeStart.getUTCFullYear(),t=Math.floor(this.rangeStart.getUTCMonth()/3),n=this.rangeEnd.getUTCFullYear(),o=Math.floor(this.rangeEnd.getUTCMonth()/3);return(n-e)*4+(o-t)}headersDay(){const e=[],t=[],n=this.getTotalWidth();let o=new Date(this.rangeStart);for(let s=0;s<this.countDays();s++){const l=s*this.columnWidth;t.push({label:String(o.getUTCDate()),x:l,width:this.columnWidth,date:new Date(o)}),o=Ve(o,1)}let i=new Date(this.rangeStart);for(;i.getTime()<this.rangeEnd.getTime();){const s=Ie(i),l=this.dateToX(i),g=s.getTime()>=this.rangeEnd.getTime()?n:this.dateToX(s);e.push({label:`${Xe[i.getUTCMonth()]} ${i.getUTCFullYear()}`,x:l,width:g-l,date:new Date(i)}),i=s}return[e,t]}headersWeek(){const e=[],t=[];this.getTotalWidth();const n=this.countWeeks();for(let i=0;i<n;i++){const s=Ve(this.rangeStart,i*7),l=i*this.columnWidth;t.push({label:`${qe[s.getUTCMonth()]} ${s.getUTCDate()}`,x:l,width:this.columnWidth,date:new Date(s)})}let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(;o.getTime()<this.rangeEnd.getTime();){const i=Ie(o),s=o.getTime()<this.rangeStart.getTime()?this.rangeStart:o,l=i.getTime()>this.rangeEnd.getTime()?this.rangeEnd:i,g=this.dateToX(s),d=this.dateToX(l);e.push({label:`${Xe[o.getUTCMonth()]} ${o.getUTCFullYear()}`,x:g,width:d-g,date:new Date(s)}),o=i}return[e,t]}headersMonth(){const e=[],t=[];this.getTotalWidth();const n=this.countMonths();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),this.rangeStart.getUTCMonth(),1));for(let s=0;s<n;s++){const l=s*this.columnWidth;t.push({label:qe[o.getUTCMonth()],x:l,width:this.columnWidth,date:new Date(o)}),o=Ie(o)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const s=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,g=s.getTime()>this.rangeEnd.getTime()?this.rangeEnd:s,d=this.dateToX(l),u=this.dateToX(g);e.push({label:String(i.getUTCFullYear()),x:d,width:u-d,date:new Date(l)}),i=s}return[e,t]}headersQuarter(){const e=[],t=[];this.getTotalWidth();const n=this.countQuarters();let o=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),Math.floor(this.rangeStart.getUTCMonth()/3)*3,1));for(let s=0;s<n;s++){const l=Math.floor(o.getUTCMonth()/3)+1,g=s*this.columnWidth;t.push({label:`Q${l}`,x:g,width:this.columnWidth,date:new Date(o)}),o=Jt(o,3)}let i=new Date(Date.UTC(this.rangeStart.getUTCFullYear(),0,1));for(;i.getTime()<this.rangeEnd.getTime();){const s=new Date(Date.UTC(i.getUTCFullYear()+1,0,1)),l=i.getTime()<this.rangeStart.getTime()?this.rangeStart:i,g=s.getTime()>this.rangeEnd.getTime()?this.rangeEnd:s,d=this.dateToX(l),u=this.dateToX(g);e.push({label:String(i.getUTCFullYear()),x:d,width:u-d,date:new Date(l)}),i=s}return[e,t]}};function Ve(e,t){return new Date(e.getTime()+t*Oe)}function Jt(e,t){const n=new Date(e);return n.setUTCMonth(n.getUTCMonth()+t),n}function Ie(e){return new Date(Date.UTC(e.getUTCFullYear(),e.getUTCMonth()+1,1))}var en=class{computeLayouts(e,t,n,o){const i=[];for(let s=0;s<e.length;s++){const l=e[s],g=t.get(l);if(!g)continue;const d=Ke(g.startDate),u=Ke(g.endDate),c=n.dateToX(d),h=n.dateToX(u)-c,p=Math.max(h,o.minBarWidth),f=s*o.rowHeight,v=f+(o.rowHeight-o.barHeight)/2,w=p*(g.progress||0),D=g.color||o.colorMap[g.status||""]||o.theme.barDefaultColor;i.push({taskId:l,rowIndex:s,x:c,y:f,width:p,barY:v,barHeight:o.barHeight,progressWidth:w,color:D,textColor:o.theme.barTextColor,label:g.status==="group-header"?g.name:(g.hoursLabel||(g.hours!=null?`${g.hours}h`:""))+(g.hoursLabel||g.hours!=null?" · ":"")+((g.progress||0)>0?`${Math.round((g.progress||0)*100)}% · `:"")+(g.title||g.name),isMilestone:g.isMilestone||!1})}return i}};function Ke(e){const[t,n,o]=e.split("-"),i=Number(t),s=Number(n)-1,l=Number(o);return new Date(Date.UTC(i,s,l))}var Me=864e5,Qe=1,tn=2,nn=.5,rn=2,Ze=8,on=6,Je=2,sn=class{constructor(e){this.displayWidth=0,this.displayHeight=0,this.canvas=document.createElement("canvas"),this.canvas.style.display="block",this.canvas.style.touchAction="none",e.appendChild(this.canvas);const t=this.canvas.getContext("2d");if(!t)throw new Error("CanvasRenderer: failed to get 2d context");this.ctx=t,this.dpr=typeof window<"u"&&window.devicePixelRatio||1}resize(e,t){this.displayWidth=e,this.displayHeight=t,this.canvas.width=Math.round(e*this.dpr),this.canvas.height=Math.round(t*this.dpr),this.canvas.style.width=`${e}px`,this.canvas.style.height=`${t}px`}render(e,t,n){const{ctx:o,displayWidth:i,displayHeight:s,dpr:l}=this,{config:g}=e,{theme:d}=g,u=e.scrollX,c=e.scrollY;o.setTransform(l,0,0,l,0,0);const h=g.headerHeight,p=s-h;this.fillRect(0,0,i,s,d.timelineBg),o.save(),o.beginPath(),o.rect(0,h,i,p),o.clip(),o.translate(-u,0),g.showWeekends&&this.renderWeekendShading(e,n,h,p,d),this.renderGridLines(n,h,p,d,u),this.renderAltRows(e,t,h,d,u,c);const f=this.getTodayX(e,g,n);g.showToday&&f!==null&&this.renderTodayBackground(f,n,h,p,d),this.renderGroupRowBgs(e,t,g,u,c,h,p),this.renderTaskBars(e,t,g,d,u,c,h,p),g.showToday&&f!==null&&this.renderTodayLine(f,h,p,d),o.restore(),this.renderHeader(n,g,d,u)}destroy(){this.canvas.remove()}renderWeekendShading(e,t,n,o,i){const{start:s,end:l}=e.dateRange,g=new Date(s);g.setUTCHours(0,0,0,0);const d=l.getTime();for(;g.getTime()<=d;){const u=g.getUTCDay();if(u===0||u===6){const c=t.dateToX(g),h=new Date(g.getTime()+Me),p=t.dateToX(h)-c;this.fillRect(c,n,p,o,i.timelineWeekendBg)}g.setTime(g.getTime()+Me)}}renderGridLines(e,t,n,o,i){const{ctx:s}=this,l=e.getGridLines();s.beginPath(),s.strokeStyle=o.timelineGridColor,s.lineWidth=nn;for(const g of l){const d=this.snapToPixel(g);s.moveTo(d,t),s.lineTo(d,t+n)}s.stroke()}renderAltRows(e,t,n,o,i,s){const{ctx:l,displayWidth:g}=this,d=e.config.rowHeight,u=e.flatVisibleIds.length;for(let c=0;c<u;c++)if(c%2===1){const h=n+c*d-s;if(h+d<n||h>n+this.displayHeight)continue;this.fillRect(i,h,g+i,d,o.gridAltRowBg)}}getTodayX(e,t,n){const o=new Date;o.setHours(0,0,0,0);const{start:i,end:s}=e.dateRange;return o.getTime()<i.getTime()||o.getTime()>s.getTime()?null:n.dateToX(o)}renderTodayBackground(e,t,n,o,i){const s=new Date;s.setHours(0,0,0,0);const l=new Date(s.getTime()+Me),g=t.dateToX(l)-t.dateToX(s);this.fillRect(e,n,g,o,i.todayBg)}renderGroupRowBgs(e,t,n,o,i,s,l){const{ctx:g,displayWidth:d}=this,u=n.rowHeight;for(const c of t){const h=e.tasks.get(c.taskId);if(!h||!h.groupBg)continue;const p=c.y-i+s;p+u<s||p>s+l||(g.save(),g.fillStyle=h.groupBg,g.fillRect(o,p,d,u),h.groupColor&&(g.fillStyle=h.groupColor,g.fillRect(o,p,d,2)),g.restore())}}renderTaskBars(e,t,n,o,i,s,l,g){const{ctx:d}=this,u=o.barBorderRadius;for(const c of t){const h=c.x,p=c.barY-s+l,f=c.width,v=c.barHeight;if(!(p+v<l||p>l+g)){if(c.isMilestone){this.renderMilestone(h,p,v,c.color,o,e.selectedIds.has(c.taskId));continue}if(this.fillRoundedRect(h,p,f,v,u,c.color),n.showProgress&&c.progressWidth>0){const w=this.darkenColor(c.color,.2);d.save(),d.beginPath(),this.roundedRectPath(h,p,f,v,u),d.clip(),d.fillStyle=w,d.fillRect(h,p,c.progressWidth,v),d.restore()}e.selectedIds.has(c.taskId)&&this.strokeRoundedRect(h,p,f,v,u,o.barSelectedBorder,Je),this.renderBarLabel(c,h,p,f,v,o)}}}renderMilestone(e,t,n,o,i,s){const{ctx:l}=this,g=(n-rn*2)/2,d=t+n/2;l.save(),l.beginPath(),l.moveTo(e,d-g),l.lineTo(e+g,d),l.lineTo(e,d+g),l.lineTo(e-g,d),l.closePath(),l.fillStyle=o,l.fill(),s&&(l.strokeStyle=i.barSelectedBorder,l.lineWidth=Je,l.stroke()),l.restore()}renderBarLabel(e,t,n,o,i,s){const{ctx:l}=this;if(!e.label)return;l.save(),l.font=`${s.fontSize}px ${s.fontFamily}`,l.textBaseline="middle";const g=l.measureText(e.label).width,d=n+i/2;g+Ze*2<=o?(l.beginPath(),l.rect(t,n,o,i),l.clip(),l.fillStyle=e.textColor,l.textAlign="left",l.fillText(e.label,t+Ze,d)):(l.fillStyle=s.gridTextColor,l.textAlign="left",l.fillText(e.label,t+o+on,d)),l.restore()}renderTodayLine(e,t,n,o){const{ctx:i}=this,s=this.snapToPixel(e);i.beginPath(),i.strokeStyle=o.todayLineColor,i.lineWidth=tn,i.moveTo(s,t),i.lineTo(s,t+n),i.stroke()}renderHeader(e,t,n,o){const{ctx:i,displayWidth:s}=this,l=t.headerHeight,g=e.getHeaderRows();i.setTransform(this.dpr,0,0,this.dpr,0,0),this.fillRect(0,0,s,l,n.timelineHeaderBg);const d=l/(g.length||2);i.font=`${n.fontSize}px ${n.fontFamily}`,i.textBaseline="middle",i.fillStyle=n.timelineHeaderText;for(let c=0;c<g.length;c++){const h=g[c],p=c*d;for(const f of h){const v=f.x-o,w=f.width;if(v+w<0||v>s)continue;i.beginPath(),i.strokeStyle=n.timelineGridColor,i.lineWidth=Qe;const D=this.snapToPixelRaw(v+w);i.moveTo(D,p),i.lineTo(D,p+d),i.stroke(),i.save(),i.beginPath(),i.rect(v,p,w,d),i.clip(),i.fillStyle=n.timelineHeaderText,i.font=c===0?`600 ${n.fontSize}px ${n.fontFamily}`:`${n.fontSize}px ${n.fontFamily}`,i.textAlign="center",i.fillText(f.label,v+w/2,p+d/2),i.restore()}}const u=this.snapToPixelRaw(l);i.beginPath(),i.strokeStyle=n.gridBorderColor,i.lineWidth=Qe,i.moveTo(0,u),i.lineTo(s,u),i.stroke()}fillRect(e,t,n,o,i){this.ctx.fillStyle=i,this.ctx.fillRect(e,t,n,o)}roundedRectPath(e,t,n,o,i){const{ctx:s}=this,l=Math.min(i,n/2,o/2);s.moveTo(e+l,t),s.lineTo(e+n-l,t),s.arcTo(e+n,t,e+n,t+l,l),s.lineTo(e+n,t+o-l),s.arcTo(e+n,t+o,e+n-l,t+o,l),s.lineTo(e+l,t+o),s.arcTo(e,t+o,e,t+o-l,l),s.lineTo(e,t+l),s.arcTo(e,t,e+l,t,l),s.closePath()}fillRoundedRect(e,t,n,o,i,s){const{ctx:l}=this;l.beginPath(),this.roundedRectPath(e,t,n,o,i),l.fillStyle=s,l.fill()}strokeRoundedRect(e,t,n,o,i,s,l){const{ctx:g}=this;g.beginPath(),this.roundedRectPath(e,t,n,o,i),g.strokeStyle=s,g.lineWidth=l,g.stroke()}snapToPixel(e){return Math.round(e)+.5}snapToPixelRaw(e){return Math.round(e)+.5}darkenColor(e,t){let n,o,i;const s=e.replace("#","");s.length===3?(n=parseInt(s[0]+s[0],16),o=parseInt(s[1]+s[1],16),i=parseInt(s[2]+s[2],16)):(n=parseInt(s.substring(0,2),16),o=parseInt(s.substring(2,4),16),i=parseInt(s.substring(4,6),16)),n=Math.round(n*(1-t)),o=Math.round(o*(1-t)),i=Math.round(i*(1-t));const l=g=>g.toString(16).padStart(2,"0");return`#${l(n)}${l(o)}${l(i)}`}},et="ng-tree-grid-styles";function an(e,t){const n=e.querySelector(`#${et}`);n&&n.remove();const o=document.createElement("style");o.id=et,o.textContent=`
    .ng-grid {
      height: 100%;
      overflow: hidden;
      border-right: 1px solid ${t.gridBorderColor};
      background: ${t.gridBg};
      font-family: ${t.fontFamily};
      font-size: ${t.fontSize}px;
      color: ${t.gridTextColor};
      display: flex;
      flex-direction: column;
      user-select: none;
      -webkit-user-select: none;
      box-sizing: border-box;
    }

    .ng-grid *, .ng-grid *::before, .ng-grid *::after {
      box-sizing: border-box;
    }

    .ng-grid table {
      width: 100%;
      border-collapse: collapse;
      table-layout: fixed;
    }

    /* ── Header ──────────────────────────────────────────────────────────── */

    .ng-grid-header {
      flex-shrink: 0;
      overflow: hidden;
      background: ${t.gridHeaderBg};
      color: ${t.gridHeaderText};
      border-bottom: 1px solid ${t.gridBorderColor};
      z-index: 2;
    }

    .ng-grid-th {
      position: relative;
      padding: 0 8px;
      text-align: left;
      font-weight: 600;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      border-right: 1px solid ${t.gridBorderColor};
      vertical-align: middle;
    }

    .ng-grid-th:last-child {
      border-right: none;
    }

    /* ── Resize Handle ───────────────────────────────────────────────────── */

    .ng-resize-handle {
      position: absolute;
      top: 0;
      right: 0;
      width: 5px;
      height: 100%;
      cursor: col-resize;
      z-index: 3;
    }

    .ng-resize-handle:hover {
      background: ${t.selectionColor};
    }

    /* ── Body ────────────────────────────────────────────────────────────── */

    .ng-grid-body {
      flex: 1;
      overflow: hidden;
      position: relative;
    }

    .ng-grid-body-inner {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
    }

    /* ── Rows ────────────────────────────────────────────────────────────── */

    .ng-grid-row {
      cursor: pointer;
      border-bottom: 1px solid ${t.gridBorderColor};
    }

    .ng-grid-row:hover {
      background: ${t.gridHoverBg};
    }

    .ng-row-alt {
      background: ${t.gridAltRowBg};
    }

    .ng-row-alt:hover {
      background: ${t.gridHoverBg};
    }

    .ng-row-selected {
      background: ${t.selectionColor} !important;
    }

    .ng-group-row {
      font-weight: 600;
      letter-spacing: 0.01em;
    }

    .ng-group-row .ng-grid-cell-text {
      opacity: 0.9;
    }

    .ng-group-row .ng-expand-icon {
      opacity: 0.75;
    }

    .ng-group-row:hover {
      filter: brightness(0.97);
    }

    /* ── Cells ───────────────────────────────────────────────────────────── */

    .ng-grid-cell {
      padding: 0 8px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      vertical-align: middle;
      border-right: 1px solid ${t.gridBorderColor};
      line-height: 1;
    }

    .ng-grid-cell:last-child {
      border-right: none;
    }

    /* ── Tree Cell ───────────────────────────────────────────────────────── */

    .ng-tree-cell {
      display: flex;
      align-items: center;
      overflow: hidden;
    }

    .ng-tree-cell > .ng-grid-cell-text {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      flex: 1;
      min-width: 0;
    }

    /* ── Expand Icon ─────────────────────────────────────────────────────── */

    .ng-expand-icon {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 16px;
      height: 16px;
      flex-shrink: 0;
      cursor: pointer;
      font-size: 10px;
      opacity: 0.65;
      transition: transform 0.15s ease;
      margin-right: 4px;
    }

    .ng-expand-icon:hover {
      opacity: 1;
    }

    .ng-expand-icon.ng-expanded {
      transform: rotate(90deg);
    }

    .ng-expand-spacer {
      display: inline-block;
      width: 16px;
      flex-shrink: 0;
      margin-right: 4px;
    }

    /* ── Drag Handle ─────────────────────────────────────────────────────── */

    .ng-drag-handle {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      cursor: grab;
      opacity: 0.3;
      font-size: 11px;
      color: #94a3b8;
      width: 14px;
      height: 14px;
      flex-shrink: 0;
      margin-left: -4px;
      margin-right: 4px;
      user-select: none;
    }

    .ng-grid-row:hover .ng-drag-handle { opacity: 0.7; }
    .ng-drag-handle:active { opacity: 1; cursor: grabbing; }

    /* ── Status Dot ──────────────────────────────────────────────────────── */

    .ng-status-dot {
      display: inline-block;
      width: 7px;
      height: 7px;
      border-radius: 50%;
      margin-right: 5px;
      flex-shrink: 0;
      vertical-align: middle;
    }
  `,e.prepend(o)}function ln(e){const t=[];function n(o){for(const i of o)i.visible&&t.push(i),i.expanded&&i.children.length>0&&n(i.children)}return n(e),t}function Te(e,t){var n,o,i;if(t.renderer)return t.renderer(e,t.field);const s=(n=(o=e[t.field])!==null&&o!==void 0?o:(i=e.metadata)==null?void 0:i[t.field])!==null&&n!==void 0?n:"";return s==null?"":String(s)}var dn=class{constructor(e){this.rows=new Map,this.clickHandler=null,this.dblClickHandler=null,this.expandHandler=null,this.resizeHandler=null,this.columnWidths=[],this.columns=[],this.currentVisibleIds=[],this.container=e,this.rootEl=document.createElement("div"),this.rootEl.className="ng-grid",this.headerEl=document.createElement("div"),this.headerEl.className="ng-grid-header";const t=document.createElement("table");this.headerColgroup=document.createElement("colgroup"),t.appendChild(this.headerColgroup);const n=document.createElement("thead");t.appendChild(n),this.headerEl.appendChild(t),this.bodyEl=document.createElement("div"),this.bodyEl.className="ng-grid-body",this.bodyInner=document.createElement("div"),this.bodyInner.className="ng-grid-body-inner";const o=document.createElement("table");this.bodyColgroup=document.createElement("colgroup"),o.appendChild(this.bodyColgroup),this.tbody=document.createElement("tbody"),o.appendChild(this.tbody),this.bodyInner.appendChild(o),this.bodyEl.appendChild(this.bodyInner),this.rootEl.appendChild(this.headerEl),this.rootEl.appendChild(this.bodyEl),this.container.appendChild(this.rootEl),this.boundBodyClick=i=>this.handleBodyClick(i),this.boundBodyDblClick=i=>this.handleBodyDblClick(i),this.bodyEl.addEventListener("click",this.boundBodyClick),this.bodyEl.addEventListener("dblclick",this.boundBodyDblClick)}render(e,t){const{config:n}=e,{columns:o,rowHeight:i}=n,s=n.theme;an(this.rootEl,s),this.columns=o,this.columnWidths=o.map(d=>{var u;return(u=d.width)!==null&&u!==void 0?u:120}),this.headerEl.style.height=`${n.headerHeight}px`,this.headerEl.style.lineHeight=`${n.headerHeight}px`,this.rebuildColgroups(),this.rebuildHeader(o,n.headerHeight);const l=ln(t),g=l.map(d=>d.task.id);this.updateRows(l,g,e),this.currentVisibleIds=g}setScrollY(e){this.bodyInner.style.transform=`translateY(${-e}px)`}onRowClick(e){this.clickHandler=e}onRowDblClick(e){this.dblClickHandler=e}onExpandToggle(e){this.expandHandler=e}onResizeColumn(e){this.resizeHandler=e}highlight(e){const t=this.rows.get(e);t&&t.classList.add("ng-row-selected")}clearHighlight(){for(const e of this.rows.values())e.classList.remove("ng-row-selected")}destroy(){this.bodyEl.removeEventListener("click",this.boundBodyClick),this.bodyEl.removeEventListener("dblclick",this.boundBodyDblClick),this.rows.clear(),this.currentVisibleIds=[],this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}rebuildColgroups(){this.headerColgroup.innerHTML="",this.bodyColgroup.innerHTML="";for(const e of this.columnWidths){const t=document.createElement("col");t.style.width=`${e}px`,this.headerColgroup.appendChild(t);const n=document.createElement("col");n.style.width=`${e}px`,this.bodyColgroup.appendChild(n)}}rebuildHeader(e,t){const n=this.headerEl.querySelector("thead"),o=n.querySelector("tr");if(o&&o.children.length===e.length){for(let s=0;s<e.length;s++){const l=o.children[s],g=l.querySelector(".ng-th-text");g&&g.textContent!==e[s].header&&(g.textContent=e[s].header),l.setAttribute("data-field",e[s].field)}return}n.innerHTML="";const i=document.createElement("tr");i.style.height=`${t}px`,e.forEach((s,l)=>{const g=document.createElement("th");g.className="ng-grid-th",g.setAttribute("data-field",s.field);const d=document.createElement("span");d.className="ng-th-text",d.textContent=s.header,g.appendChild(d);const u=document.createElement("span");u.className="ng-resize-handle",g.appendChild(u),this.attachResizeListener(u,l),i.appendChild(g)}),n.appendChild(i)}attachResizeListener(e,t){e.addEventListener("mousedown",n=>{var o;n.preventDefault(),n.stopPropagation();const i=n.clientX,s=this.columnWidths[t],l=(o=this.columns[t].minWidth)!==null&&o!==void 0?o:40,g=u=>{const c=u.clientX-i,h=Math.max(l,s+c);this.columnWidths[t]=h;const p=this.headerColgroup.children,f=this.bodyColgroup.children;p[t]&&(p[t].style.width=`${h}px`),f[t]&&(f[t].style.width=`${h}px`)},d=()=>{document.removeEventListener("mousemove",g),document.removeEventListener("mouseup",d),this.resizeHandler&&this.resizeHandler(this.columns[t].field,this.columnWidths[t])};document.addEventListener("mousemove",g),document.addEventListener("mouseup",d)})}updateRows(e,t,n){const{config:o}=n,{rowHeight:i}=o,s=new Set(t),l=new Map;for(const d of e)l.set(d.task.id,d);for(const[d,u]of this.rows)s.has(d)||(u.remove(),this.rows.delete(d));let g=null;for(let d=0;d<e.length;d++){const u=e[d],c=u.task.id;let h=this.rows.get(c);h?this.updateRowContent(h,u,d,n):(h=this.createRow(u,d,n),this.rows.set(c,h)),h.style.height=`${i}px`,g?g.nextSibling!==h&&this.tbody.insertBefore(h,g.nextSibling):this.tbody.firstChild!==h&&this.tbody.insertBefore(h,this.tbody.firstChild),g=h}}createRow(e,t,n){const{config:o}=n,{columns:i,rowHeight:s}=o,l=document.createElement("tr");l.className="ng-grid-row",l.setAttribute("data-task-id",e.task.id),l.style.height=`${s}px`,e.task.status==="group-header"?(l.classList.add("ng-group-row"),e.task.groupBg&&(l.style.background=e.task.groupBg)):t%2===1&&l.classList.add("ng-row-alt"),n.selectedIds.has(e.task.id)&&l.classList.add("ng-row-selected");for(const g of i){const d=this.createCell(e,g,n);l.appendChild(d)}return l}createCell(e,t,n){var o;const i=document.createElement("td");if(i.className="ng-grid-cell",i.setAttribute("data-field",t.field),t.align==="center"?i.style.textAlign="center":t.align==="right"&&(i.style.textAlign="right"),t.tree){var s;i.classList.add("ng-tree-cell");const l=e.depth*20+8;if(i.style.paddingLeft=`${l}px`,e.children.length>0){const u=document.createElement("span");u.className="ng-expand-icon",e.expanded&&u.classList.add("ng-expanded"),u.innerHTML="&#9654;",u.setAttribute("data-expand",e.task.id),i.appendChild(u)}else{const u=document.createElement("span");u.className="ng-expand-spacer",i.appendChild(u)}if(e.children.length===0&&!e.task.groupBg){const u=document.createElement("span");u.className="ng-drag-handle",u.innerHTML="&#9776;",i.appendChild(u)}const g=e.task.color||((o=n.config.colorMap)==null?void 0:o[(s=e.task.status)!==null&&s!==void 0?s:""])||"";if(g&&e.children.length===0){const u=document.createElement("span");u.className="ng-status-dot",u.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${g};margin-right:5px;flex-shrink:0;vertical-align:middle;`,i.appendChild(u)}const d=document.createElement("span");d.className="ng-grid-cell-text",d.textContent=Te(e.task,t),i.appendChild(d)}else if(t.field==="_drag"&&e.children.length===0&&!e.task.groupBg){const l=document.createElement("span");l.className="ng-drag-handle",l.innerHTML="&#9776;",i.appendChild(l)}else i.textContent=Te(e.task,t);return i}updateRowContent(e,t,n,o){var i;const{config:s}=o,{columns:l}=s;t.task.status==="group-header"?(e.classList.add("ng-group-row"),t.task.groupBg&&(e.style.background=t.task.groupBg),e.classList.remove("ng-row-alt")):(e.classList.remove("ng-group-row"),e.style.background="",n%2===1?e.classList.add("ng-row-alt"):e.classList.remove("ng-row-alt")),o.selectedIds.has(t.task.id)?e.classList.add("ng-row-selected"):e.classList.remove("ng-row-selected");const g=e.querySelectorAll("td.ng-grid-cell");for(let u=0;u<l.length;u++){const c=l[u],h=g[u];if(!h){const p=this.createCell(t,c,o);e.appendChild(p);continue}if(c.tree){var d;const p=t.depth*20+8;h.style.paddingLeft=`${p}px`;const f=h.querySelector(".ng-expand-icon"),v=h.querySelector(".ng-expand-spacer");if(t.children.length>0)if(f)t.expanded?f.classList.add("ng-expanded"):f.classList.remove("ng-expanded");else{v&&v.remove();const I=document.createElement("span");I.className="ng-expand-icon",t.expanded&&I.classList.add("ng-expanded"),I.innerHTML="&#9654;",I.setAttribute("data-expand",t.task.id),h.insertBefore(I,h.firstChild)}else if(f){f.remove();const I=document.createElement("span");I.className="ng-expand-spacer",h.insertBefore(I,h.firstChild)}const w=h.querySelector(".ng-drag-handle");if(t.children.length===0&&!t.task.groupBg){if(!w){const I=document.createElement("span");I.className="ng-drag-handle",I.innerHTML="&#9776;";const B=h.querySelector(".ng-status-dot")||h.querySelector(".ng-grid-cell-text");B?h.insertBefore(I,B):h.appendChild(I)}}else w&&w.remove();const D=h.querySelector(".ng-status-dot"),T=t.task.color||((i=o.config.colorMap)==null?void 0:i[(d=t.task.status)!==null&&d!==void 0?d:""])||"";if(T&&t.children.length===0)if(D)D.style.background=T;else{const I=document.createElement("span");I.className="ng-status-dot",I.style.cssText=`display:inline-block;width:7px;height:7px;border-radius:50%;background:${T};margin-right:5px;flex-shrink:0;vertical-align:middle;`;const B=h.querySelector(".ng-grid-cell-text");B?h.insertBefore(I,B):h.appendChild(I)}else D&&D.remove();const H=h.querySelector(".ng-grid-cell-text");if(H){const I=Te(t.task,c);H.textContent!==I&&(H.textContent=I)}}else if(c.field==="_drag"){const p=h.querySelector(".ng-drag-handle");if(t.children.length===0&&!t.task.groupBg){if(!p){h.textContent="";const f=document.createElement("span");f.className="ng-drag-handle",f.innerHTML="&#9776;",h.appendChild(f)}}else p&&(h.textContent="")}else{const p=Te(t.task,c);h.textContent!==p&&(h.textContent=p)}}for(;e.children.length>l.length;)e.removeChild(e.lastChild)}findTaskId(e){let t=e;for(;t&&t!==this.bodyEl;){if(t.hasAttribute("data-task-id"))return t.getAttribute("data-task-id");t=t.parentElement}return null}handleBodyClick(e){const t=e.target;if(t.hasAttribute("data-expand")||t.closest(".ng-expand-icon")){const o=t.hasAttribute("data-expand")?t:t.closest(".ng-expand-icon");if(o&&this.expandHandler){const i=o.getAttribute("data-expand");if(i){e.stopPropagation(),this.expandHandler(i);return}}}const n=this.findTaskId(e.target);n&&this.clickHandler&&this.clickHandler(n,e)}handleBodyDblClick(e){const t=this.findTaskId(e.target);t&&this.dblClickHandler&&this.dblClickHandler(t,e)}},cn=class{constructor(e,t){for(this.rafId=null,this.pendingScroll=!1,this.onScrollCallback=t,this.wrapper=document.createElement("div"),this.wrapper.className="ng-scroll-wrapper",this.wrapper.style.cssText="position: absolute; inset: 0; overflow: auto; will-change: scroll-position;",this.content=document.createElement("div"),this.content.className="ng-scroll-content",this.content.style.cssText="position: relative; min-width: 100%; min-height: 100%;";e.firstChild;){const n=e.firstChild;n.style&&(n.style.position="sticky",n.style.top="0",n.style.left="0",n.style.zIndex="1"),this.content.appendChild(n)}this.wrapper.appendChild(this.content),e.appendChild(this.wrapper),this.boundOnScroll=this.handleScroll.bind(this),this.wrapper.addEventListener("scroll",this.boundOnScroll,{passive:!0})}setScrollPosition(e,t){this.wrapper.scrollLeft=e,this.wrapper.scrollTop=t}getScrollPosition(){return{x:this.wrapper.scrollLeft,y:this.wrapper.scrollTop}}setContentSize(e,t){this.content.style.width=`${e}px`,this.content.style.height=`${t}px`}setViewportSize(e,t){this.wrapper.style.width=`${e}px`,this.wrapper.style.height=`${t}px`}scrollToX(e){this.wrapper.scrollLeft=e}scrollToY(e){this.wrapper.scrollTop=e}destroy(){this.wrapper.removeEventListener("scroll",this.boundOnScroll),this.rafId!==null&&(cancelAnimationFrame(this.rafId),this.rafId=null)}handleScroll(){this.pendingScroll||(this.pendingScroll=!0,this.rafId=requestAnimationFrame(()=>{this.pendingScroll=!1,this.rafId=null,this.onScrollCallback(this.wrapper.scrollLeft,this.wrapper.scrollTop)}))}},un=class{constructor(){this.edgeThreshold=6,this.linkPointRadius=8}test(e,t,n,o){for(let i=n.length-1;i>=0;i--){const s=n[i],l=this.testLayout(e,t,s,o);if(l!==null)return{type:l,taskId:s.taskId,layout:s}}return null}getCursor(e,t){if(!e)return"default";switch(e.type){case"bar":return t?"default":"grab";case"bar-left-edge":case"bar-right-edge":return"col-resize";case"progress-handle":return"ew-resize";case"link-point":return"crosshair";default:return"default"}}testLayout(e,t,n,o){return n.isMilestone?this.testMilestone(e,t,n):this.testBar(e,t,n,o)}testBar(e,t,n,o){const{x:i,barY:s,width:l,barHeight:g}=n;if(e<i||e>i+l||t<s||t>s+g)return null;if(e<=i+this.edgeThreshold)return"bar-left-edge";if(e>=i+l-this.edgeThreshold)return"bar-right-edge";if(o.showProgress&&n.progressWidth>0){const d=i+n.progressWidth;if(Math.abs(e-d)<=this.edgeThreshold)return"progress-handle"}return"bar"}testMilestone(e,t,n){const o=n.x,i=n.barY+n.barHeight/2,s=n.barHeight/2;return Math.abs(e-o)<=s&&Math.abs(t-i)<=s?"bar":null}},tt=864e5;function Pe(e,t){const n=t.xToDate(0),o=t.xToDate(e);return Math.round((o.getTime()-n.getTime())/tt)}function ye(e){const[t,n,o]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(o)))}function ue(e,t){const n=ye(e),o=new Date(n.getTime()+t*tt);return`${o.getUTCFullYear()}-${String(o.getUTCMonth()+1).padStart(2,"0")}-${String(o.getUTCDate()).padStart(2,"0")}`}function gn(e,t,n){return Math.max(t,Math.min(n,e))}var fn=3,hn=300,pn=class{constructor(e,t){this.dragging=!1,this.dragHit=null,this.dragStartX=0,this.dragStartY=0,this.dragPointerId=null,this.dragOriginalStartDate="",this.dragOriginalEndDate="",this.lastClickTaskId=null,this.lastClickTime=0,this.canvas=e,this.options=t,this.hitTest=new un,this.onPointerDown=this.handlePointerDown.bind(this),this.onPointerMove=this.handlePointerMove.bind(this),this.onPointerUp=this.handlePointerUp.bind(this),this.onClick=this.handleClick_native.bind(this),this.canvas.addEventListener("pointerdown",this.onPointerDown),this.canvas.addEventListener("pointermove",this.onPointerMove),this.canvas.addEventListener("pointerup",this.onPointerUp),this.canvas.addEventListener("click",this.onClick)}destroy(){if(this.canvas.removeEventListener("pointerdown",this.onPointerDown),this.canvas.removeEventListener("pointermove",this.onPointerMove),this.canvas.removeEventListener("pointerup",this.onPointerUp),this.canvas.removeEventListener("click",this.onClick),this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch(e){}this.dragPointerId=null}this.dragging=!1,this.dragHit=null}toCanvasCoords(e){const t=this.canvas.getBoundingClientRect(),n=this.options.getState(),o=e.clientX-t.left,i=e.clientY-t.top;return{canvasX:o+n.scrollX,canvasY:i+n.scrollY-n.config.headerHeight}}handleClick_native(e){const{canvasX:t,canvasY:n}=this.toCanvasCoordsFromMouse(e),o=this.options.getState(),i=this.options.getLayouts(),s=this.hitTest.test(t,n,i,o.config);s&&s.type!=="none"&&(e.preventDefault(),e.stopPropagation())}toCanvasCoordsFromMouse(e){const t=this.canvas.getBoundingClientRect(),n=this.options.getState(),o=e.clientX-t.left,i=e.clientY-t.top;return{canvasX:o+n.scrollX,canvasY:i+n.scrollY-n.config.headerHeight}}handlePointerMove(e){if(this.dragging){this.handleDragMove(e);return}const{canvasX:t,canvasY:n}=this.toCanvasCoords(e),o=this.options.getState(),i=this.options.getLayouts(),s=this.hitTest.test(t,n,i,o.config);if(this.canvas.style.cursor=this.hitTest.getCursor(s,this.options.readOnly),this.options.onHover)if(s&&s.type!=="none"){const l=o.tasks.get(s.taskId);if(l){const g=this.canvas.getBoundingClientRect();this.options.onHover(l,e.clientX-g.left,e.clientY-g.top,s.layout.color)}}else this.options.onHover(null,0,0,"")}handlePointerDown(e){if(e.button!==0)return;const{canvasX:t,canvasY:n}=this.toCanvasCoords(e),o=this.options.getState(),i=this.options.getLayouts(),s=this.hitTest.test(t,n,i,o.config);if(!s||s.type==="none")return;e.preventDefault(),e.stopPropagation(),this.dragHit=s,this.dragStartX=e.clientX,this.dragStartY=e.clientY;const l=o.tasks.get(s.taskId);if(l&&(this.dragOriginalStartDate=l.startDate,this.dragOriginalEndDate=l.endDate,this.canvas.setPointerCapture(e.pointerId),this.dragPointerId=e.pointerId,this.dragging=!0,!this.options.readOnly)){const g=mn(s.type);g&&this.options.dispatch({type:"DRAG_START",drag:{type:g,taskId:s.taskId,startX:t,startY:n,currentX:t,currentY:n,originalStartDate:l.startDate,originalEndDate:l.endDate}})}}handleDragMove(e){if(!this.dragHit||(e.preventDefault(),this.options.readOnly))return;const{canvasX:t,canvasY:n}=this.toCanvasCoords(e);this.options.dispatch({type:"DRAG_UPDATE",currentX:t,currentY:n})}handlePointerUp(e){if(this.dragPointerId!==null){try{this.canvas.releasePointerCapture(this.dragPointerId)}catch(l){}this.dragPointerId=null}if(!this.dragging||!this.dragHit){this.dragging=!1,this.dragHit=null;return}const t=Math.abs(e.clientX-this.dragStartX),n=Math.abs(e.clientY-this.dragStartY),o=Math.sqrt(t*t+n*n),i=this.dragHit,s=this.options.getState().tasks.get(i.taskId);o<fn?(this.options.dispatch({type:"DRAG_END"}),s&&this.handleClick(s)):this.options.readOnly?this.options.dispatch({type:"DRAG_END"}):this.completeDrag(e),this.dragging=!1,this.dragHit=null}handleClick(e){var t,n,o,i;const s=Date.now();if(this.lastClickTaskId===e.id&&s-this.lastClickTime<hn){this.lastClickTaskId=null,this.lastClickTime=0,(n=(t=this.options).onTaskDblClick)==null||n.call(t,e);return}this.lastClickTaskId=e.id,this.lastClickTime=s,this.options.dispatch({type:"SELECT_TASK",taskId:e.id}),(i=(o=this.options).onTaskClick)==null||i.call(o,e)}completeDrag(e){var t,n,o,i,s,l,g,d;if(!this.dragHit)return;const u=this.options.getState(),c=u.tasks.get(this.dragHit.taskId);if(!c){this.options.dispatch({type:"DRAG_END"});return}const h=this.options.getTimeScale();u.config;const p=this.dragHit.type,f=e.clientX-this.dragStartX;switch(p){case"bar":{const v=Pe(f,h),w=ue(this.dragOriginalStartDate,v),D=ue(this.dragOriginalEndDate,v);this.options.dispatch({type:"TASK_MOVE",taskId:c.id,startDate:w,endDate:D}),(n=(t=this.options).onTaskMove)==null||n.call(t,c,w,D);break}case"bar-left-edge":{const v=Pe(f,h),w=ue(this.dragOriginalStartDate,v),D=ye(this.dragOriginalEndDate),T=ye(w).getTime()>=D.getTime()?ue(this.dragOriginalEndDate,-1):w;this.options.dispatch({type:"TASK_RESIZE",taskId:c.id,startDate:T,endDate:this.dragOriginalEndDate}),(i=(o=this.options).onTaskResize)==null||i.call(o,c,T,this.dragOriginalEndDate);break}case"bar-right-edge":{const v=Pe(f,h),w=ue(this.dragOriginalEndDate,v),D=ye(this.dragOriginalStartDate),T=ye(w).getTime()<=D.getTime()?ue(this.dragOriginalStartDate,1):w;this.options.dispatch({type:"TASK_RESIZE",taskId:c.id,startDate:this.dragOriginalStartDate,endDate:T}),(l=(s=this.options).onTaskResize)==null||l.call(s,c,this.dragOriginalStartDate,T);break}case"progress-handle":{const v=this.dragHit.layout,{canvasX:w}=this.toCanvasCoords(e),D=gn((w-v.x)/v.width,0,1),T=Math.round(D*100)/100;this.options.dispatch({type:"UPDATE_TASK",taskId:c.id,changes:{progress:T}}),(d=(g=this.options).onTaskProgressChange)==null||d.call(g,c,T);break}}this.options.dispatch({type:"DRAG_END"})}};function mn(e){switch(e){case"bar":return"move";case"bar-left-edge":return"resize-left";case"bar-right-edge":return"resize-right";case"progress-handle":return"progress";case"link-point":return"link";default:return null}}var ge=12,ke=6,Ee=4,bn=3,yn=class{render(e,t,n,o,i,s,l){const{dependencies:g}=t;if(g.size===0)return;const d=new Map;for(const h of n)d.set(h.taskId,h);const u=e.canvas.width/(window.devicePixelRatio||1),c=e.canvas.height/(window.devicePixelRatio||1);e.save(),e.beginPath(),e.rect(0,l,u,c-l),e.clip(),e.translate(-i,0);for(const h of g.values()){const p=d.get(h.source),f=d.get(h.target);if(!p||!f)continue;const v=h.type||"FS",{sourceX:w,sourceY:D,targetX:T,targetY:H}=this.getConnectionPoints(v,p,f,s,l);this.drawRoutedPath(e,v,w,D,T,H,o),this.drawArrowhead(e,v,T,H,o),this.drawConnectionDot(e,w,D,o),this.drawConnectionDot(e,T,H,o)}e.restore()}getConnectionPoints(e,t,n,o,i){const s=t.barY+t.barHeight/2-o+i,l=n.barY+n.barHeight/2-o+i;switch(e){case"FS":return{sourceX:t.x+t.width,sourceY:s,targetX:n.x,targetY:l};case"SS":return{sourceX:t.x,sourceY:s,targetX:n.x,targetY:l};case"FF":return{sourceX:t.x+t.width,sourceY:s,targetX:n.x+n.width,targetY:l};case"SF":return{sourceX:t.x,sourceY:s,targetX:n.x+n.width,targetY:l}}}drawRoutedPath(e,t,n,o,i,s,l){e.beginPath(),e.strokeStyle=l.dependencyColor,e.lineWidth=l.dependencyWidth,e.moveTo(n,o);const g=t==="FS"||t==="FF",d=t==="FS"||t==="SS",u=g?n+ge:n-ge,c=d?i-ge:i+ge;if(g?d?c>=u:i+ge>=u:d?i-ge<=u:c<=u)e.lineTo(u,o),e.lineTo(u,s),e.lineTo(i,s);else{const h=(o+s)/2;e.lineTo(u,o),e.lineTo(u,h),e.lineTo(c,h),e.lineTo(c,s),e.lineTo(i,s)}e.stroke()}drawArrowhead(e,t,n,o,i){const s=t==="FS"||t==="SS";e.beginPath(),s?(e.moveTo(n,o),e.lineTo(n-ke,o-Ee),e.lineTo(n-ke,o+Ee)):(e.moveTo(n,o),e.lineTo(n+ke,o-Ee),e.lineTo(n+ke,o+Ee)),e.closePath(),e.fillStyle=i.dependencyColor,e.fill()}drawConnectionDot(e,t,n,o){e.beginPath(),e.arc(t,n,bn,0,Math.PI*2),e.fillStyle=o.dependencyColor,e.fill()}},Se=12,vn=100,wn=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],xn=`
.ng-tooltip {
  position: absolute;
  z-index: 1000;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  padding: 0;
  pointer-events: none;
  font-size: 12px;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  min-width: 180px;
  max-width: 280px;
  opacity: 0;
  transform: translateY(4px);
  transition: opacity 0.15s ease, transform 0.15s ease;
}
.ng-tooltip.ng-tooltip-visible {
  opacity: 1;
  transform: translateY(0);
}
.ng-tooltip-header {
  padding: 8px 10px;
  border-bottom: 1px solid #f3f4f6;
  font-weight: 600;
  color: #111827;
}
.ng-tooltip-body {
  padding: 6px 10px;
}
.ng-tooltip-row {
  display: flex;
  justify-content: space-between;
  padding: 2px 0;
}
.ng-tooltip-label {
  color: #6b7280;
}
.ng-tooltip-value {
  color: #111827;
  font-weight: 500;
}
`;function fe(e){return e.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}function nt(e){const t=e.split("-");if(t.length!==3)return fe(e);const n=parseInt(t[1],10)-1,o=parseInt(t[2],10);return n<0||n>11||isNaN(o)?fe(e):`${wn[n]} ${o}`}function ve(e,t){return`<div class="ng-tooltip-row"><span class="ng-tooltip-label">${fe(e)}</span><span class="ng-tooltip-value">${fe(t)}</span></div>`}function Tn(e,t){var n,o,i;const s=Math.round(((n=e.progress)!==null&&n!==void 0?n:0)*100),l=(o=e.metadata)==null?void 0:o.estimatedHours,g=(i=e.metadata)==null?void 0:i.loggedHours;let d="";return d+=ve("Status",e.status||"None"),d+=ve("Assignee",e.assignee||"Unassigned"),d+=ve("Dates",`${nt(e.startDate)} → ${nt(e.endDate)}`),s>0&&(d+=ve("Progress",`${s}%`)),l!=null&&(d+=ve("Hours",`${g!=null?g:0} / ${l}`)),`<div class="ng-tooltip-header" style="border-left: 3px solid ${fe(t)}"><span class="ng-tooltip-name">${fe(e.name)}</span></div><div class="ng-tooltip-body">${d}</div>`}var kn=class{constructor(e,t){this.visible=!1,this.hideTimeout=null,this.container=e,this.customRenderer=t,this.styleEl=document.createElement("style"),this.styleEl.textContent=xn,document.head.appendChild(this.styleEl),this.tooltipEl=document.createElement("div"),this.tooltipEl.className="ng-tooltip",this.tooltipEl.style.display="none",this.container.appendChild(this.tooltipEl)}show(e,t,n,o){if(this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.customRenderer){const d=this.customRenderer(e);typeof d=="string"?this.tooltipEl.innerHTML=d:(this.tooltipEl.innerHTML="",this.tooltipEl.appendChild(d))}else this.tooltipEl.innerHTML=Tn(e,o);this.tooltipEl.style.display="",this.tooltipEl.classList.remove("ng-tooltip-visible");const i=this.tooltipEl.getBoundingClientRect(),s=this.container.getBoundingClientRect();let l=t+Se,g=n+Se;l+i.width>s.width&&(l=t-Se-i.width),g+i.height>s.height&&(g=n-Se-i.height),l=Math.max(0,l),g=Math.max(0,g),this.tooltipEl.style.left=`${l}px`,this.tooltipEl.style.top=`${g}px`,requestAnimationFrame(()=>{this.tooltipEl.classList.add("ng-tooltip-visible")}),this.visible=!0}hide(){this.visible&&(this.hideTimeout!==null&&clearTimeout(this.hideTimeout),this.hideTimeout=window.setTimeout(()=>{this.tooltipEl.classList.remove("ng-tooltip-visible");const e=()=>{this.tooltipEl.removeEventListener("transitionend",e),this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")};this.tooltipEl.addEventListener("transitionend",e),window.setTimeout(()=>{this.tooltipEl.classList.contains("ng-tooltip-visible")||(this.tooltipEl.style.display="none")},200),this.visible=!1,this.hideTimeout=null},vn))}destroy(){this.hideTimeout!==null&&(clearTimeout(this.hideTimeout),this.hideTimeout=null),this.tooltipEl.remove(),this.styleEl.remove()}},rt={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barBorderRadius:4,barProgressOpacity:.3,barTextColor:"#ffffff",barSelectedBorder:"#1d4ed8",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#111827",gridHeaderBg:"#f3f4f6",gridHeaderText:"#374151",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",dependencyWidth:1.5,criticalPathColor:"#ef4444",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(59, 130, 246, 0.1)"},En={timelineBg:"#1f2937",timelineGridColor:"#374151",timelineHeaderBg:"#111827",timelineHeaderText:"#d1d5db",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barBorderRadius:4,barProgressOpacity:.35,barTextColor:"#ffffff",barSelectedBorder:"#93bbfd",gridBg:"#1f2937",gridAltRowBg:"#111827",gridBorderColor:"#374151",gridTextColor:"#e5e7eb",gridHeaderBg:"#111827",gridHeaderText:"#d1d5db",gridHoverBg:"#374151",dependencyColor:"#6b7280",dependencyWidth:1.5,criticalPathColor:"#f87171",fontFamily:'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',fontSize:12,selectionColor:"rgba(96, 165, 250, 0.15)"},Sn=[{field:"name",header:"Task",width:200,tree:!0},{field:"assignee",header:"Assignee",width:100}];function _n(e){var t,n,o,i,s,l,g,d,u,c,h,p,f,v;const w=Cn(e.theme);return{columns:(t=e.columns)!==null&&t!==void 0?t:Sn,zoomLevel:(n=e.zoomLevel)!==null&&n!==void 0?n:"week",rowHeight:(o=e.rowHeight)!==null&&o!==void 0?o:36,barHeight:(i=e.barHeight)!==null&&i!==void 0?i:24,headerHeight:(s=e.headerHeight)!==null&&s!==void 0?s:56,gridWidth:(l=e.gridWidth)!==null&&l!==void 0?l:300,minBarWidth:(g=e.minBarWidth)!==null&&g!==void 0?g:8,readOnly:(d=e.readOnly)!==null&&d!==void 0?d:!1,fitToView:(u=e.fitToView)!==null&&u!==void 0?u:!0,showToday:(c=e.showToday)!==null&&c!==void 0?c:!0,showWeekends:(h=e.showWeekends)!==null&&h!==void 0?h:!0,showProgress:(p=e.showProgress)!==null&&p!==void 0?p:!0,snapToDays:(f=e.snapToDays)!==null&&f!==void 0?f:!0,colorMap:(v=e.colorMap)!==null&&v!==void 0?v:{},theme:w}}function Cn(e){return!e||e==="light"?R({},rt):e==="dark"?R({},En):R(R({},rt),e)}var ot="nimbus-gantt-root-styles";function Rn(){if(typeof document>"u"||document.getElementById(ot))return;const e=document.createElement("style");e.id=ot,e.textContent=`
    .nimbus-gantt {
      display: flex;
      width: 100%;
      height: 100%;
      overflow: hidden;
      position: relative;
      font-family: var(--ng-font-family);
    }
    .ng-grid-panel {
      flex-shrink: 0;
      overflow: hidden;
      border-right: 1px solid var(--ng-border-color);
    }
    .ng-timeline-panel {
      flex: 1;
      overflow: hidden;
      position: relative;
    }
  `,document.head.appendChild(e)}var Dn=class{constructor(e,t){this.dragManager=null,this.plugins=[],this.pluginMiddlewares=[],this.layouts=[],this.renderScheduled=!1,this.destroyed=!1,this.container=e,this.config=_n(t),Rn(),this.rootEl=document.createElement("div"),this.rootEl.className="nimbus-gantt",this.rootEl.style.setProperty("--ng-font-family",this.config.theme.fontFamily),this.rootEl.style.setProperty("--ng-border-color",this.config.theme.gridBorderColor),this.gridPanel=document.createElement("div"),this.gridPanel.className="ng-grid-panel",this.gridPanel.style.width=this.config.gridWidth>0?`${this.config.gridWidth}px`:"0px",this.config.gridWidth===0&&(this.gridPanel.style.display="none"),this.timelinePanel=document.createElement("div"),this.timelinePanel.className="ng-timeline-panel",this.rootEl.appendChild(this.gridPanel),this.rootEl.appendChild(this.timelinePanel),this.container.appendChild(this.rootEl);const n=new Map;for(const u of t.tasks)n.set(u.id,u);const o=new Map;if(t.dependencies)for(const u of t.dependencies)o.set(u.id,u);const i=new Set,{tree:s,flatIds:l}=le(n,i),g=be(n),d={tasks:n,dependencies:o,tree:s,flatVisibleIds:l,expandedIds:i,selectedIds:new Set,zoomLevel:this.config.zoomLevel,scrollX:0,scrollY:0,dateRange:g,dragState:null,config:this.config};if(this.eventBus=new Vt,this.store=new Ge(d),this.layoutEngine=new en,this.timeScale=this.createTimeScale(d),this.canvasRenderer=new sn(this.timelinePanel),this.treeGrid=new dn(this.gridPanel),this.scrollManager=new cn(this.timelinePanel,(u,c)=>{this.store.dispatch({type:"SET_SCROLL",x:u,y:c})}),this.dependencyRenderer=new yn,this.tooltipManager=new kn(this.timelinePanel,t.tooltipRenderer),!this.config.readOnly){const u=this.timelinePanel.querySelector("canvas");u&&(this.dragManager=new pn(u,{getLayouts:()=>this.layouts,getState:()=>this.store.getState(),getTimeScale:()=>({dateToX:c=>this.timeScale.dateToX(c),xToDate:c=>this.timeScale.xToDate(c),getColumnWidth:()=>this.timeScale.getColumnWidth()}),dispatch:c=>this.store.dispatch(c),onTaskMove:t.onTaskMove,onTaskResize:t.onTaskResize,onTaskProgressChange:t.onTaskProgressChange,onTaskClick:c=>{this.eventBus.emit("taskClick",c)},onTaskDblClick:c=>{this.eventBus.emit("taskDblClick",c)},onHover:(c,h,p,f)=>{c?this.tooltipManager.show(c,h,p,f):this.tooltipManager.hide()},readOnly:this.config.readOnly,headerHeight:this.config.headerHeight}))}this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()}),this.treeGrid.onRowClick((u,c)=>{this.store.dispatch({type:"SELECT_TASK",taskId:u,multi:c.ctrlKey||c.metaKey}),this.eventBus.emit("taskClick",this.store.getState().tasks.get(u))}),this.treeGrid.onRowDblClick(u=>{this.eventBus.emit("taskDblClick",this.store.getState().tasks.get(u))}),this.treeGrid.onExpandToggle(u=>{this.store.dispatch({type:"TOGGLE_EXPAND",taskId:u})}),this.wireCallbacks(t),this.resizeObserver=new ResizeObserver(()=>{this.destroyed||this.resize()}),this.resizeObserver.observe(this.container),this.resize(),this.render()}setData(e,t){this.store.dispatch({type:"SET_DATA",tasks:e,dependencies:t})}updateTask(e,t){this.store.dispatch({type:"UPDATE_TASK",taskId:e,changes:t})}addTask(e){this.store.dispatch({type:"ADD_TASK",task:e})}removeTask(e){this.store.dispatch({type:"REMOVE_TASK",taskId:e})}setZoom(e){this.store.dispatch({type:"SET_ZOOM",level:e}),this.eventBus.emit("viewChange",e)}scrollToDate(e){const t=typeof e=="string"?new Date(e):e,n=this.timeScale.dateToX(t),o=this.timelinePanel.clientWidth,i=Math.max(0,n-o/2);this.scrollManager.scrollToX(i)}scrollToTask(e){const t=this.store.getState(),n=t.flatVisibleIds.indexOf(e);if(n===-1)return;const{rowHeight:o,headerHeight:i}=t.config,s=this.timelinePanel.clientHeight-i,l=Math.max(0,n*o-s/2+o/2);this.scrollManager.scrollToY(l);const g=t.tasks.get(e);g&&this.scrollToDate(g.startDate)}expandAll(){this.store.dispatch({type:"EXPAND_ALL"})}collapseAll(){this.store.dispatch({type:"COLLAPSE_ALL"})}expandTask(e){this.store.getState().expandedIds.has(e)||this.store.dispatch({type:"TOGGLE_EXPAND",taskId:e})}collapseTask(e){this.store.getState().expandedIds.has(e)&&this.store.dispatch({type:"TOGGLE_EXPAND",taskId:e})}getVisibleDateRange(){const e=this.store.getState();return{start:e.dateRange.start.toISOString().split("T")[0],end:e.dateRange.end.toISOString().split("T")[0]}}use(e){const t=this.createPluginHost();if(e.install(t),e.middleware){const n=(o,i,s)=>{e.middleware(o,s)};this.pluginMiddlewares.push(n),this.rebuildStoreWithMiddleware()}this.plugins.push(e)}render(){if(this.destroyed)return;this.renderScheduled=!1;const e=this.store.getState(),t=this.timelinePanel.clientWidth;this.timeScale=this.createTimeScale(e,t),this.layouts=this.layoutEngine.computeLayouts(e.flatVisibleIds,e.tasks,this.timeScale,e.config);const n=this.timeScale.getTotalWidth(),o=e.config.headerHeight+e.flatVisibleIds.length*e.config.rowHeight;this.scrollManager.setContentSize(n,o);const i=this.timelinePanel.clientWidth,s=this.timelinePanel.clientHeight;if(this.canvasRenderer.resize(i,s),this.canvasRenderer.render(e,this.layouts,this.timeScale),e.dependencies.size>0){const l=this.timelinePanel.querySelector("canvas");if(l){const g=l.getContext("2d");g&&this.dependencyRenderer.render(g,e,this.layouts,e.config.theme,e.scrollX,e.scrollY,e.config.headerHeight)}}this.treeGrid.render(e,e.tree),this.treeGrid.setScrollY(e.scrollY),this.treeGrid.clearHighlight();for(const l of e.selectedIds)this.treeGrid.highlight(l);for(const l of this.plugins){if(l.renderCanvas){const g=this.timelinePanel.querySelector("canvas");if(g){const d=g.getContext("2d");d&&l.renderCanvas(d,e,this.layouts)}}l.renderDOM&&l.renderDOM(this.rootEl,e)}this.eventBus.emit("render")}resize(){this.destroyed||this.render()}destroy(){if(!this.destroyed){this.destroyed=!0,this.resizeObserver.disconnect(),this.scrollManager.destroy(),this.dragManager&&this.dragManager.destroy(),this.tooltipManager.destroy(),this.canvasRenderer.destroy(),this.treeGrid.destroy();for(const e of this.plugins)e.destroy&&e.destroy();this.plugins=[],this.unsubscribeStore(),this.rootEl.parentElement&&this.rootEl.parentElement.removeChild(this.rootEl)}}createTimeScale(e,t){const n=t!=null?t:this.timelinePanel.clientWidth||800;return new Zt(e.zoomLevel,e.dateRange,n)}scheduleRender(){this.renderScheduled||this.destroyed||(this.renderScheduled=!0,requestAnimationFrame(()=>{this.render()}))}wireCallbacks(e){e.onTaskClick&&this.eventBus.on("taskClick",(...t)=>{const n=t[0];n&&e.onTaskClick(n)}),e.onTaskDblClick&&this.eventBus.on("taskDblClick",(...t)=>{const n=t[0];n&&e.onTaskDblClick(n)}),e.onTaskMove&&this.eventBus.on("taskMove",(...t)=>{e.onTaskMove(t[0],t[1],t[2])}),e.onTaskResize&&this.eventBus.on("taskResize",(...t)=>{e.onTaskResize(t[0],t[1],t[2])}),e.onTaskProgressChange&&this.eventBus.on("taskProgressChange",(...t)=>{e.onTaskProgressChange(t[0],t[1])}),e.onDependencyCreate&&this.eventBus.on("dependencyCreate",(...t)=>{e.onDependencyCreate(t[0],t[1],t[2])}),e.onDependencyClick&&this.eventBus.on("dependencyClick",(...t)=>{e.onDependencyClick(t[0])}),e.onViewChange&&this.eventBus.on("viewChange",(...t)=>{const n=this.store.getState();e.onViewChange(t[0],n.dateRange.start.toISOString().split("T")[0],n.dateRange.end.toISOString().split("T")[0])}),e.onTaskSelect&&this.store.subscribe(()=>{const t=this.store.getState();e.onTaskSelect(Array.from(t.selectedIds))})}createPluginHost(){return{getState:()=>this.store.getState(),dispatch:e=>this.store.dispatch(e),on:(e,t)=>this.eventBus.on(e,t),getLayouts:()=>this.layouts,getTimeScale:()=>({dateToX:e=>this.timeScale.dateToX(e),xToDate:e=>this.timeScale.xToDate(e),getColumnWidth:()=>this.timeScale.getColumnWidth()}),rebuildTree:()=>{const e=this.store.getState(),{tree:t,flatIds:n}=le(e.tasks,e.expandedIds);e.tree=t,e.flatVisibleIds.length=0;for(const o of n)e.flatVisibleIds.push(o)}}}rebuildStoreWithMiddleware(){const e=this.store.getState();this.unsubscribeStore(),this.store=new Ge(e,[...this.pluginMiddlewares]),this.unsubscribeStore=this.store.subscribe(()=>{this.scheduleRender()})}},it=300,ar="nimbus-gantt-config-panel",lr="nimbus-gantt-config-panel-styles",st=300,dr=[{name:"Light",values:{timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f9fafb",timelineHeaderText:"#374151",timelineWeekendBg:"rgba(0, 0, 0, 0.02)",todayLineColor:"#ef4444",todayBg:"rgba(239, 68, 68, 0.06)",barDefaultColor:"#3b82f6",barTextColor:"#ffffff",barSelectedBorder:"#2563eb",gridBg:"#ffffff",gridAltRowBg:"#f9fafb",gridBorderColor:"#e5e7eb",gridTextColor:"#374151",gridHeaderBg:"#f3f4f6",gridHeaderText:"#111827",gridHoverBg:"#f3f4f6",dependencyColor:"#9ca3af",criticalPathColor:"#ef4444",selectionColor:"rgba(59, 130, 246, 0.12)"}},{name:"Dark",values:{timelineBg:"#1a1a2e",timelineGridColor:"#2d2d44",timelineHeaderBg:"#16213e",timelineHeaderText:"#e2e8f0",timelineWeekendBg:"rgba(255, 255, 255, 0.03)",todayLineColor:"#f87171",todayBg:"rgba(248, 113, 113, 0.08)",barDefaultColor:"#60a5fa",barTextColor:"#ffffff",barSelectedBorder:"#93c5fd",gridBg:"#1a1a2e",gridAltRowBg:"#1e1e36",gridBorderColor:"#2d2d44",gridTextColor:"#e2e8f0",gridHeaderBg:"#16213e",gridHeaderText:"#e2e8f0",gridHoverBg:"#2a2a42",dependencyColor:"#64748b",criticalPathColor:"#f87171",selectionColor:"rgba(96, 165, 250, 0.15)"}},{name:"High Contrast",values:{timelineBg:"#000000",timelineGridColor:"#444444",timelineHeaderBg:"#1a1a1a",timelineHeaderText:"#ffffff",timelineWeekendBg:"rgba(255, 255, 255, 0.06)",todayLineColor:"#ff0000",todayBg:"rgba(255, 0, 0, 0.12)",barDefaultColor:"#00ccff",barTextColor:"#000000",barSelectedBorder:"#ffffff",gridBg:"#000000",gridAltRowBg:"#111111",gridBorderColor:"#555555",gridTextColor:"#ffffff",gridHeaderBg:"#1a1a1a",gridHeaderText:"#ffffff",gridHoverBg:"#222222",dependencyColor:"#aaaaaa",criticalPathColor:"#ff0000",selectionColor:"rgba(0, 204, 255, 0.2)"}},{name:"Midnight Blue",values:{timelineBg:"#0f172a",timelineGridColor:"#1e293b",timelineHeaderBg:"#0c1524",timelineHeaderText:"#cbd5e1",timelineWeekendBg:"rgba(255, 255, 255, 0.02)",todayLineColor:"#f59e0b",todayBg:"rgba(245, 158, 11, 0.08)",barDefaultColor:"#6366f1",barTextColor:"#ffffff",barSelectedBorder:"#818cf8",gridBg:"#0f172a",gridAltRowBg:"#131d33",gridBorderColor:"#1e293b",gridTextColor:"#cbd5e1",gridHeaderBg:"#0c1524",gridHeaderText:"#e2e8f0",gridHoverBg:"#1e293b",dependencyColor:"#475569",criticalPathColor:"#f59e0b",selectionColor:"rgba(99, 102, 241, 0.15)"}}],cr=`
  .ng-config-gear {
    position: absolute;
    bottom: 16px;
    right: 16px;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: rgba(59, 130, 246, 0.9);
    color: #fff;
    border: none;
    cursor: pointer;
    font-size: 20px;
    line-height: 40px;
    text-align: center;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
    z-index: 1000;
    transition: background 200ms ease, transform 200ms ease;
    user-select: none;
  }
  .ng-config-gear:hover {
    background: rgba(59, 130, 246, 1);
    transform: scale(1.08);
  }

  .ng-config-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.35);
    z-index: 1001;
    opacity: 0;
    pointer-events: none;
    transition: opacity ${st}ms ease;
  }
  .ng-config-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-config-panel {
    position: absolute;
    top: 0;
    right: -${it}px;
    width: ${it}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${st}ms ease;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 13px;
  }
  .ng-config-panel.ng-open {
    right: 0;
  }

  .ng-config-panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 16px;
    border-bottom: 1px solid #333;
    font-size: 15px;
    font-weight: 600;
  }

  .ng-config-close {
    background: none;
    border: none;
    color: #999;
    font-size: 20px;
    cursor: pointer;
    padding: 0 4px;
    line-height: 1;
  }
  .ng-config-close:hover {
    color: #fff;
  }

  .ng-config-section {
    border-bottom: 1px solid #2a2a3a;
    padding: 12px 16px;
  }
  .ng-config-section-title {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #888;
    margin-bottom: 10px;
    font-weight: 600;
  }

  .ng-config-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 8px;
  }
  .ng-config-row:last-child {
    margin-bottom: 0;
  }
  .ng-config-label {
    font-size: 12px;
    color: #ccc;
    flex-shrink: 0;
  }

  .ng-config-slider {
    width: 110px;
    accent-color: #3b82f6;
    cursor: pointer;
  }
  .ng-config-slider-value {
    font-size: 11px;
    color: #888;
    width: 32px;
    text-align: right;
    flex-shrink: 0;
  }

  .ng-config-toggle {
    position: relative;
    width: 36px;
    height: 20px;
    background: #444;
    border-radius: 10px;
    cursor: pointer;
    transition: background 200ms ease;
    flex-shrink: 0;
  }
  .ng-config-toggle.ng-active {
    background: #3b82f6;
  }
  .ng-config-toggle-knob {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 16px;
    height: 16px;
    background: #fff;
    border-radius: 50%;
    transition: left 200ms ease;
  }
  .ng-config-toggle.ng-active .ng-config-toggle-knob {
    left: 18px;
  }

  .ng-config-select {
    background: #2a2a3a;
    color: #e0e0e0;
    border: 1px solid #444;
    border-radius: 4px;
    padding: 4px 8px;
    font-size: 12px;
    cursor: pointer;
    outline: none;
  }
  .ng-config-select:focus {
    border-color: #3b82f6;
  }

  .ng-config-color-input {
    width: 32px;
    height: 24px;
    padding: 0;
    border: 1px solid #444;
    border-radius: 4px;
    cursor: pointer;
    background: transparent;
  }

  .ng-config-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 6px 12px;
    background: #2a2a3a;
    color: #ccc;
    border: 1px solid #444;
    border-radius: 4px;
    font-size: 12px;
    cursor: pointer;
    transition: background 150ms ease;
    margin-right: 6px;
    margin-bottom: 6px;
  }
  .ng-config-btn:hover {
    background: #3b3b4a;
    color: #fff;
  }
  .ng-config-btn.ng-primary {
    background: #3b82f6;
    border-color: #3b82f6;
    color: #fff;
  }
  .ng-config-btn.ng-primary:hover {
    background: #2563eb;
  }

  .ng-config-zoom-group {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }
  .ng-config-zoom-btn {
    padding: 4px 10px;
    background: #2a2a3a;
    color: #ccc;
    border: 1px solid #444;
    border-radius: 4px;
    font-size: 11px;
    cursor: pointer;
    transition: background 150ms ease;
  }
  .ng-config-zoom-btn:hover {
    background: #3b3b4a;
  }
  .ng-config-zoom-btn.ng-active {
    background: #3b82f6;
    border-color: #3b82f6;
    color: #fff;
  }

  .ng-config-date-input {
    background: #2a2a3a;
    color: #e0e0e0;
    border: 1px solid #444;
    border-radius: 4px;
    padding: 3px 6px;
    font-size: 11px;
    width: 110px;
    outline: none;
  }
  .ng-config-date-input:focus {
    border-color: #3b82f6;
  }

  .ng-config-color-map-entry {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 6px;
  }
  .ng-config-color-map-status {
    flex: 1;
    background: #2a2a3a;
    color: #e0e0e0;
    border: 1px solid #444;
    border-radius: 4px;
    padding: 3px 6px;
    font-size: 11px;
    outline: none;
  }
  .ng-config-color-map-remove {
    background: none;
    border: none;
    color: #888;
    cursor: pointer;
    font-size: 14px;
    padding: 0 2px;
  }
  .ng-config-color-map-remove:hover {
    color: #ef4444;
  }
  .ng-config-color-map-add {
    font-size: 11px;
    color: #3b82f6;
    cursor: pointer;
    background: none;
    border: none;
    padding: 2px 0;
  }
  .ng-config-color-map-add:hover {
    text-decoration: underline;
  }

  .ng-config-plugin-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 4px 0;
  }
  .ng-config-plugin-name {
    font-size: 12px;
    color: #ccc;
  }
  .ng-config-plugin-status {
    font-size: 10px;
    color: #888;
    margin-left: 6px;
  }
  .ng-config-plugin-status.ng-active-status {
    color: #22c55e;
  }
`,On=200,In=80,at=12,lt=6,ur="rgba(255, 255, 255, 0.95)",Mn="#cbd5e1",gr="rgba(59, 130, 246, 0.3)",fr="rgba(59, 130, 246, 0.7)",hr=1.5,pr=2,mr=1,br="nimbus-gantt-minimap-styles",yr=864e5,vr=`
  .ng-minimap {
    position: absolute;
    bottom: ${at}px;
    right: ${at}px;
    width: ${On}px;
    height: ${In}px;
    z-index: 900;
    border-radius: ${lt}px;
    border: 1px solid ${Mn};
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12);
    overflow: hidden;
    cursor: pointer;
    user-select: none;
    transition: opacity 200ms ease, transform 200ms ease;
  }
  .ng-minimap.ng-hidden {
    opacity: 0;
    pointer-events: none;
    transform: scale(0.9);
  }
  .ng-minimap canvas {
    display: block;
    border-radius: ${lt}px;
  }
`,wr=500,Pn=40,dt=7,ct=3,ut=5,xr=500,Tr="nimbus-gantt-timetravel-styles",kr={move:"#3B82F6",add:"#22C55E",remove:"#EF4444",resize:"#F97316",update:"#A78BFA",data:"#94A3B8"},Er=`
  .ng-timetravel {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${Pn}px;
    background: linear-gradient(180deg, #1e293b 0%, #0f172a 100%);
    border-top: 1px solid #334155;
    display: flex;
    align-items: center;
    padding: 0 8px;
    gap: 6px;
    z-index: 950;
    user-select: none;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 11px;
    color: #94A3B8;
  }
  .ng-timetravel.ng-hidden {
    display: none;
  }
  .ng-timetravel-btn {
    background: #334155;
    border: 1px solid #475569;
    border-radius: 4px;
    color: #CBD5E1;
    cursor: pointer;
    padding: 2px 6px;
    font-size: 11px;
    line-height: 18px;
    transition: background 150ms ease, border-color 150ms ease;
    flex-shrink: 0;
  }
  .ng-timetravel-btn:hover {
    background: #475569;
    border-color: #64748B;
    color: #F1F5F9;
  }
  .ng-timetravel-btn.ng-active {
    background: #3B82F6;
    border-color: #60A5FA;
    color: #FFF;
  }
  .ng-timetravel-btn.ng-present {
    background: #065F46;
    border-color: #10B981;
    color: #A7F3D0;
  }
  .ng-timetravel-btn.ng-present:hover {
    background: #047857;
  }
  .ng-timetravel-track {
    flex: 1;
    height: 20px;
    position: relative;
    cursor: pointer;
    margin: 0 4px;
  }
  .ng-timetravel-rail {
    position: absolute;
    top: 50%;
    left: 0;
    right: 0;
    height: 2px;
    background: #475569;
    transform: translateY(-50%);
    border-radius: 1px;
  }
  .ng-timetravel-playhead {
    position: absolute;
    top: 50%;
    width: ${dt*2}px;
    height: ${dt*2}px;
    background: #3B82F6;
    border: 2px solid #93C5FD;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    cursor: grab;
    z-index: 2;
    transition: background 100ms ease;
    box-shadow: 0 0 6px rgba(59, 130, 246, 0.5);
  }
  .ng-timetravel-playhead:hover {
    background: #60A5FA;
  }
  .ng-timetravel-playhead.ng-dragging {
    cursor: grabbing;
    background: #93C5FD;
  }
  .ng-timetravel-dot {
    position: absolute;
    top: 50%;
    width: ${ct*2}px;
    height: ${ct*2}px;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    z-index: 1;
    transition: width 100ms ease, height 100ms ease;
    pointer-events: all;
  }
  .ng-timetravel-dot:hover {
    width: ${ut*2}px;
    height: ${ut*2}px;
  }
  .ng-timetravel-tooltip {
    position: absolute;
    bottom: 100%;
    left: 50%;
    transform: translateX(-50%);
    background: #1E293B;
    border: 1px solid #475569;
    border-radius: 6px;
    padding: 6px 10px;
    white-space: nowrap;
    font-size: 11px;
    color: #E2E8F0;
    pointer-events: none;
    opacity: 0;
    transition: opacity 150ms ease;
    z-index: 10;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
    margin-bottom: 4px;
  }
  .ng-timetravel-dot:hover .ng-timetravel-tooltip {
    opacity: 1;
  }
  .ng-timetravel-counter {
    flex-shrink: 0;
    min-width: 60px;
    text-align: center;
    font-variant-numeric: tabular-nums;
  }
  .ng-timetravel-speed {
    flex-shrink: 0;
    min-width: 28px;
    text-align: center;
  }
`,Sr=864e5,gt=400,_r="nimbus-gantt-narrative-styles",ft=300,Cr=`
  .ng-narrative-btn {
    position: absolute;
    bottom: 16px;
    right: 64px;
    height: 36px;
    padding: 0 14px;
    border-radius: 18px;
    background: rgba(99, 102, 241, 0.9);
    color: #fff;
    border: none;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
    z-index: 1000;
    transition: background 200ms ease, transform 200ms ease;
    user-select: none;
    display: flex;
    align-items: center;
    gap: 6px;
    line-height: 1;
  }
  .ng-narrative-btn:hover {
    background: rgba(99, 102, 241, 1);
    transform: scale(1.04);
  }
  .ng-narrative-btn-icon {
    font-size: 16px;
  }

  .ng-narrative-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.35);
    z-index: 1001;
    opacity: 0;
    pointer-events: none;
    transition: opacity ${ft}ms ease;
  }
  .ng-narrative-overlay.ng-visible {
    opacity: 1;
    pointer-events: auto;
  }

  .ng-narrative-panel {
    position: absolute;
    top: 0;
    right: -${gt}px;
    width: ${gt}px;
    height: 100%;
    background: #1e1e2e;
    color: #e0e0e0;
    z-index: 1002;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -4px 0 16px rgba(0, 0, 0, 0.3);
    transition: right ${ft}ms ease;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 13px;
  }
  .ng-narrative-panel.ng-open {
    right: 0;
  }

  .ng-narrative-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 16px;
    border-bottom: 1px solid #333;
    font-size: 15px;
    font-weight: 600;
    position: sticky;
    top: 0;
    background: #1e1e2e;
    z-index: 1;
  }
  .ng-narrative-header-left {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .ng-narrative-close {
    background: none;
    border: none;
    color: #999;
    font-size: 20px;
    cursor: pointer;
    padding: 0 4px;
    line-height: 1;
  }
  .ng-narrative-close:hover {
    color: #fff;
  }

  .ng-narrative-refresh {
    background: none;
    border: none;
    color: #888;
    font-size: 16px;
    cursor: pointer;
    padding: 2px 6px;
    border-radius: 4px;
    transition: color 150ms, background 150ms;
  }
  .ng-narrative-refresh:hover {
    color: #fff;
    background: rgba(255,255,255,0.08);
  }

  .ng-narrative-summary {
    padding: 16px;
    border-bottom: 1px solid #2a2a3a;
    font-size: 13px;
    line-height: 1.6;
    color: #cbd5e1;
  }

  .ng-narrative-chapter {
    border-bottom: 1px solid #2a2a3a;
  }

  .ng-narrative-chapter-header {
    padding: 12px 16px;
    font-weight: 600;
    font-size: 13px;
    border-left: 4px solid;
  }
  .ng-narrative-chapter-header.ng-good {
    border-left-color: #22c55e;
    background: rgba(34, 197, 94, 0.06);
  }
  .ng-narrative-chapter-header.ng-mixed {
    border-left-color: #f59e0b;
    background: rgba(245, 158, 11, 0.06);
  }
  .ng-narrative-chapter-header.ng-troubled {
    border-left-color: #ef4444;
    background: rgba(239, 68, 68, 0.06);
  }
  .ng-narrative-chapter-header.ng-quiet {
    border-left-color: #64748b;
    background: rgba(100, 116, 139, 0.06);
  }

  .ng-narrative-week-label {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: #888;
    margin-bottom: 4px;
  }

  .ng-narrative-headline {
    font-size: 13px;
    color: #e2e8f0;
  }

  .ng-narrative-metrics {
    display: flex;
    gap: 6px;
    padding: 8px 16px;
    flex-wrap: wrap;
  }

  .ng-narrative-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
  }
  .ng-narrative-badge.ng-started {
    background: rgba(59, 130, 246, 0.15);
    color: #60a5fa;
  }
  .ng-narrative-badge.ng-completed {
    background: rgba(34, 197, 94, 0.15);
    color: #4ade80;
  }
  .ng-narrative-badge.ng-delayed {
    background: rgba(239, 68, 68, 0.15);
    color: #f87171;
  }
  .ng-narrative-badge.ng-ontrack {
    background: rgba(245, 158, 11, 0.15);
    color: #fbbf24;
  }

  .ng-narrative-body {
    padding: 8px 16px 16px;
    font-size: 12.5px;
    line-height: 1.65;
    color: #94a3b8;
  }

  .ng-narrative-insights {
    padding: 16px;
  }
  .ng-narrative-insights-title {
    font-size: 14px;
    font-weight: 600;
    margin-bottom: 12px;
    color: #e2e8f0;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .ng-narrative-insight {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    margin-bottom: 10px;
    font-size: 12.5px;
    line-height: 1.55;
    color: #94a3b8;
  }
  .ng-narrative-insight-icon {
    flex-shrink: 0;
    font-size: 14px;
    margin-top: 1px;
  }

  .ng-narrative-empty {
    padding: 40px 16px;
    text-align: center;
    color: #64748b;
    font-size: 13px;
  }

  .ng-narrative-timestamp {
    padding: 12px 16px;
    font-size: 10px;
    color: #475569;
    text-align: center;
    border-top: 1px solid #2a2a3a;
  }
`,Rr=864e5,Dr=10,Or="nimbus-gantt-whatif-styles",Ir=.25,Mr=.6,Pr=6,An="#38A169",Hn="#E53E3E",Ln="#A0AEC0",Ae=36,Bn="#F6AD55",ht="#1a202c",Ar=`
  .ng-whatif-banner {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: ${Ae}px;
    background: ${Bn};
    color: ${ht};
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 12px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 13px;
    font-weight: 600;
    z-index: 1000;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
    user-select: none;
    transition: opacity 200ms ease;
  }
  .ng-whatif-banner.ng-hidden {
    opacity: 0;
    pointer-events: none;
    height: 0;
    overflow: hidden;
  }
  .ng-whatif-banner-left {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .ng-whatif-badge {
    background: rgba(0, 0, 0, 0.15);
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .ng-whatif-change-count {
    font-weight: 400;
    font-size: 12px;
    opacity: 0.8;
  }
  .ng-whatif-banner-right {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .ng-whatif-btn {
    border: none;
    background: rgba(0, 0, 0, 0.1);
    color: ${ht};
    padding: 4px 10px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: background 150ms ease;
  }
  .ng-whatif-btn:hover {
    background: rgba(0, 0, 0, 0.2);
  }
  .ng-whatif-btn--danger {
    background: rgba(229, 62, 62, 0.2);
    color: #9B2C2C;
  }
  .ng-whatif-btn--danger:hover {
    background: rgba(229, 62, 62, 0.35);
  }
  .ng-whatif-btn--primary {
    background: rgba(49, 130, 206, 0.2);
    color: #2B6CB0;
  }
  .ng-whatif-btn--primary:hover {
    background: rgba(49, 130, 206, 0.35);
  }

  .ng-whatif-save-input {
    display: none;
    align-items: center;
    gap: 4px;
  }
  .ng-whatif-save-input.ng-active {
    display: flex;
  }
  .ng-whatif-save-input input {
    width: 140px;
    padding: 3px 6px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: 3px;
    font-size: 12px;
    background: rgba(255, 255, 255, 0.9);
    color: #1a202c;
    outline: none;
  }
  .ng-whatif-save-input input:focus {
    border-color: #3182ce;
    box-shadow: 0 0 0 2px rgba(49, 130, 206, 0.3);
  }

  .ng-whatif-panel {
    position: absolute;
    top: ${Ae}px;
    left: 0;
    bottom: 0;
    width: 280px;
    background: rgba(26, 32, 44, 0.97);
    border-right: 1px solid #2d3748;
    z-index: 950;
    transform: translateX(-100%);
    transition: transform 250ms ease;
    overflow-y: auto;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    color: #e2e8f0;
    padding: 16px;
  }
  .ng-whatif-panel.ng-open {
    transform: translateX(0);
  }
  .ng-whatif-panel-title {
    font-size: 14px;
    font-weight: 700;
    margin-bottom: 12px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .ng-whatif-panel-close {
    border: none;
    background: none;
    color: #a0aec0;
    cursor: pointer;
    font-size: 16px;
    padding: 2px 6px;
    border-radius: 3px;
  }
  .ng-whatif-panel-close:hover {
    background: rgba(255, 255, 255, 0.1);
    color: #fff;
  }
  .ng-whatif-scenario-card {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid #2d3748;
    border-radius: 6px;
    padding: 10px 12px;
    margin-bottom: 8px;
    cursor: pointer;
    transition: border-color 150ms ease, background 150ms ease;
  }
  .ng-whatif-scenario-card:hover {
    border-color: #4a5568;
    background: rgba(255, 255, 255, 0.08);
  }
  .ng-whatif-scenario-name {
    font-weight: 600;
    font-size: 13px;
    margin-bottom: 4px;
  }
  .ng-whatif-scenario-meta {
    font-size: 11px;
    color: #a0aec0;
    display: flex;
    gap: 8px;
  }
  .ng-whatif-scenario-actions {
    display: flex;
    gap: 4px;
    margin-top: 6px;
  }
  .ng-whatif-scenario-btn {
    border: none;
    background: rgba(255, 255, 255, 0.08);
    color: #a0aec0;
    padding: 2px 8px;
    border-radius: 3px;
    font-size: 11px;
    cursor: pointer;
  }
  .ng-whatif-scenario-btn:hover {
    background: rgba(255, 255, 255, 0.15);
    color: #e2e8f0;
  }
  .ng-whatif-scenario-btn--delete:hover {
    background: rgba(229, 62, 62, 0.3);
    color: #fc8181;
  }
  .ng-whatif-empty {
    font-size: 12px;
    color: #718096;
    text-align: center;
    padding: 20px 0;
  }

  .ng-whatif-summary {
    position: absolute;
    top: ${Ae+8}px;
    right: 12px;
    background: rgba(26, 32, 44, 0.95);
    border: 1px solid #2d3748;
    border-radius: 8px;
    padding: 12px 16px;
    z-index: 960;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 12px;
    color: #e2e8f0;
    min-width: 240px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
    transition: opacity 200ms ease, transform 200ms ease;
  }
  .ng-whatif-summary.ng-hidden {
    opacity: 0;
    pointer-events: none;
    transform: translateY(-8px);
  }
  .ng-whatif-summary-title {
    font-weight: 700;
    font-size: 13px;
    margin-bottom: 8px;
  }
  .ng-whatif-summary-row {
    display: flex;
    justify-content: space-between;
    padding: 3px 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  }
  .ng-whatif-summary-row:last-child {
    border-bottom: none;
  }
  .ng-whatif-summary-label {
    color: #a0aec0;
  }
  .ng-whatif-summary-value {
    font-weight: 600;
  }
  .ng-whatif-summary-value--improved {
    color: ${An};
  }
  .ng-whatif-summary-value--worsened {
    color: ${Hn};
  }
  .ng-whatif-summary-value--unchanged {
    color: ${Ln};
  }
`,Hr="nimbus-gantt-sonification-styles",$n=64,Lr=64,Br=.05,$r=.1,Nr=.7,zr=.2,jr="#F6AD55",Wr=2,Yr="rgba(246, 173, 85, 0.35)",Ur=12,Fr=`
  .ng-sonification-controls {
    position: absolute;
    bottom: 12px;
    left: 12px;
    display: flex;
    align-items: center;
    gap: 8px;
    background: rgba(26, 32, 44, 0.95);
    border: 1px solid #2d3748;
    border-radius: 8px;
    padding: 8px 12px;
    z-index: 900;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 12px;
    color: #e2e8f0;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
    user-select: none;
    transition: opacity 200ms ease;
  }
  .ng-sonification-controls.ng-hidden {
    opacity: 0;
    pointer-events: none;
  }
  .ng-son-btn {
    border: none;
    background: rgba(255, 255, 255, 0.08);
    color: #e2e8f0;
    width: 32px;
    height: 32px;
    border-radius: 6px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 14px;
    transition: background 150ms ease;
  }
  .ng-son-btn:hover {
    background: rgba(255, 255, 255, 0.15);
  }
  .ng-son-btn--active {
    background: rgba(246, 173, 85, 0.25);
    color: #F6AD55;
  }
  .ng-son-sep {
    width: 1px;
    height: 24px;
    background: #2d3748;
  }
  .ng-son-label {
    font-size: 10px;
    color: #a0aec0;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .ng-son-slider {
    width: 60px;
    height: 4px;
    -webkit-appearance: none;
    appearance: none;
    background: #2d3748;
    border-radius: 2px;
    outline: none;
    cursor: pointer;
  }
  .ng-son-slider::-webkit-slider-thumb {
    -webkit-appearance: none;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: #e2e8f0;
    cursor: pointer;
  }
  .ng-son-slider::-moz-range-thumb {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: #e2e8f0;
    border: none;
    cursor: pointer;
  }
  .ng-son-select {
    background: #2d3748;
    color: #e2e8f0;
    border: 1px solid #4a5568;
    border-radius: 4px;
    padding: 2px 4px;
    font-size: 11px;
    cursor: pointer;
    outline: none;
  }

  .ng-sonification-waveform {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: ${$n}px;
    z-index: 850;
    pointer-events: none;
    transition: opacity 300ms ease;
  }
  .ng-sonification-waveform.ng-hidden {
    opacity: 0;
  }
  .ng-sonification-waveform canvas {
    display: block;
    width: 100%;
    height: 100%;
  }
`,Nn=ae((e=>{var t=Symbol.for("react.transitional.element"),n=Symbol.for("react.fragment");function o(i,s,l){var g=null;if(l!==void 0&&(g=""+l),s.key!==void 0&&(g=""+s.key),"key"in s){l={};for(var d in s)d!=="key"&&(l[d]=s[d])}else l=s;return s=l.ref,{$$typeof:t,type:i,key:g,ref:s!==void 0?s:null,props:l}}e.Fragment=n,e.jsx=o,e.jsxs=o})),zn=ae((e=>{process.env.NODE_ENV!=="production"&&(function(){function t(a){if(a==null)return null;if(typeof a=="function")return a.$$typeof===F?null:a.displayName||a.name||null;if(typeof a=="string")return a;switch(a){case T:return"Fragment";case I:return"Profiler";case H:return"StrictMode";case A:return"Suspense";case C:return"SuspenseList";case J:return"Activity"}if(typeof a=="object")switch(typeof a.tag=="number"&&console.error("Received an unexpected object in getComponentNameFromType(). This is likely a bug in React. Please file an issue."),a.$$typeof){case D:return"Portal";case y:return a.displayName||"Context";case B:return(a._context.displayName||"Context")+".Consumer";case L:var b=a.render;return a=a.displayName,a||(a=b.displayName||b.name||"",a=a!==""?"ForwardRef("+a+")":"ForwardRef"),a;case U:return b=a.displayName||null,b!==null?b:t(a.type)||"Memo";case K:b=a._payload,a=a._init;try{return t(a(b))}catch(k){}}return null}function n(a){return""+a}function o(a){try{n(a);var b=!1}catch(_){b=!0}if(b){b=console;var k=b.error,E=typeof Symbol=="function"&&Symbol.toStringTag&&a[Symbol.toStringTag]||a.constructor.name||"Object";return k.call(b,"The provided key is an unsupported type %s. This value must be coerced to a string before using it here.",E),n(a)}}function i(a){if(a===T)return"<>";if(typeof a=="object"&&a!==null&&a.$$typeof===K)return"<...>";try{var b=t(a);return b?"<"+b+">":"<...>"}catch(k){return"<...>"}}function s(){var a=ie.A;return a===null?null:a.getOwner()}function l(){return Error("react-stack-top-frame")}function g(a){if(ee.call(a,"key")){var b=Object.getOwnPropertyDescriptor(a,"key").get;if(b&&b.isReactWarning)return!1}return a.key!==void 0}function d(a,b){function k(){G||(G=!0,console.error("%s: `key` is not a prop. Trying to access it will result in `undefined` being returned. If you need to access the same value within the child component, you should pass it as a different prop. (https://react.dev/link/special-props)",b))}k.isReactWarning=!0,Object.defineProperty(a,"key",{get:k,configurable:!0})}function u(){var a=t(this.type);return Z[a]||(Z[a]=!0,console.error("Accessing element.ref was removed in React 19. ref is now a regular prop. It will be removed from the JSX Element type in a future release.")),a=this.props.ref,a!==void 0?a:null}function c(a,b,k,E,_,$){var M=k.ref;return a={$$typeof:w,type:a,key:b,props:k,_owner:E},(M!==void 0?M:null)!==null?Object.defineProperty(a,"ref",{enumerable:!1,get:u}):Object.defineProperty(a,"ref",{enumerable:!1,value:null}),a._store={},Object.defineProperty(a._store,"validated",{configurable:!1,enumerable:!1,writable:!0,value:0}),Object.defineProperty(a,"_debugInfo",{configurable:!1,enumerable:!1,writable:!0,value:null}),Object.defineProperty(a,"_debugStack",{configurable:!1,enumerable:!1,writable:!0,value:_}),Object.defineProperty(a,"_debugTask",{configurable:!1,enumerable:!1,writable:!0,value:$}),Object.freeze&&(Object.freeze(a.props),Object.freeze(a)),a}function h(a,b,k,E,_,$){var M=b.children;if(M!==void 0)if(E)if(te(M)){for(E=0;E<M.length;E++)p(M[E]);Object.freeze&&Object.freeze(M)}else console.error("React.jsx: Static children should always be an array. You are likely explicitly calling React.jsxs or React.jsxDEV. Use the Babel transform instead.");else p(M);if(ee.call(b,"key")){M=t(a);var Q=Object.keys(b).filter(function(he){return he!=="key"});E=0<Q.length?"{key: someKey, "+Q.join(": ..., ")+": ...}":"{key: someKey}",re[M+E]||(Q=0<Q.length?"{"+Q.join(": ..., ")+": ...}":"{}",console.error(`A props object containing a "key" prop is being spread into JSX:
  let props = %s;
  <%s {...props} />
React keys must be passed directly to JSX without using spread:
  let props = %s;
  <%s key={someKey} {...props} />`,E,M,Q,M),re[M+E]=!0)}if(M=null,k!==void 0&&(o(k),M=""+k),g(b)&&(o(b.key),M=""+b.key),"key"in b){k={};for(var V in b)V!=="key"&&(k[V]=b[V])}else k=b;return M&&d(k,typeof a=="function"?a.displayName||a.name||"Unknown":a),c(a,M,k,s(),_,$)}function p(a){f(a)?a._store&&(a._store.validated=1):typeof a=="object"&&a!==null&&a.$$typeof===K&&(a._payload.status==="fulfilled"?f(a._payload.value)&&a._payload.value._store&&(a._payload.value._store.validated=1):a._store&&(a._store.validated=1))}function f(a){return typeof a=="object"&&a!==null&&a.$$typeof===w}var v=xe(),w=Symbol.for("react.transitional.element"),D=Symbol.for("react.portal"),T=Symbol.for("react.fragment"),H=Symbol.for("react.strict_mode"),I=Symbol.for("react.profiler"),B=Symbol.for("react.consumer"),y=Symbol.for("react.context"),L=Symbol.for("react.forward_ref"),A=Symbol.for("react.suspense"),C=Symbol.for("react.suspense_list"),U=Symbol.for("react.memo"),K=Symbol.for("react.lazy"),J=Symbol.for("react.activity"),F=Symbol.for("react.client.reference"),ie=v.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE,ee=Object.prototype.hasOwnProperty,te=Array.isArray,q=console.createTask?console.createTask:function(){return null};v={react_stack_bottom_frame:function(a){return a()}};var G,Z={},ne=v.react_stack_bottom_frame.bind(v,l)(),se=q(i(l)),re={};e.Fragment=T,e.jsx=function(a,b,k){var E=1e4>ie.recentlyCreatedOwnerStacks++;return h(a,b,k,!1,E?Error("react-stack-top-frame"):ne,E?q(i(a)):se)},e.jsxs=function(a,b,k){var E=1e4>ie.recentlyCreatedOwnerStacks++;return h(a,b,k,!0,E?Error("react-stack-top-frame"):ne,E?q(i(a)):se)}})()})),jn=ae(((e,t)=>{process.env.NODE_ENV==="production"?t.exports=Nn():t.exports=zn()})),P=jn(),He,Le,Be,pt=(He=(Le=Dn)!==null&&Le!==void 0?Le:(Be=void 0)===null||Be===void 0?void 0:Be.NimbusGantt)!==null&&He!==void 0?He:void 0,Wn=(0,Y.forwardRef)(function(t,n){const o=(0,Y.useRef)(null),i=(0,Y.useRef)(null),s=(0,Y.useRef)(!1),l=(0,Y.useRef)({onTaskClick:t.onTaskClick,onTaskDblClick:t.onTaskDblClick,onTaskHover:t.onTaskHover,onTaskMove:t.onTaskMove,onTaskResize:t.onTaskResize,onTaskProgressChange:t.onTaskProgressChange,onDependencyCreate:t.onDependencyCreate,onDependencyClick:t.onDependencyClick,onViewChange:t.onViewChange,onTaskSelect:t.onTaskSelect});(0,Y.useEffect)(()=>{l.current={onTaskClick:t.onTaskClick,onTaskDblClick:t.onTaskDblClick,onTaskHover:t.onTaskHover,onTaskMove:t.onTaskMove,onTaskResize:t.onTaskResize,onTaskProgressChange:t.onTaskProgressChange,onDependencyCreate:t.onDependencyCreate,onDependencyClick:t.onDependencyClick,onViewChange:t.onViewChange,onTaskSelect:t.onTaskSelect}});const g=(0,Y.useMemo)(()=>({columns:t.columns,zoomLevel:t.zoomLevel,rowHeight:t.rowHeight,barHeight:t.barHeight,headerHeight:t.headerHeight,gridWidth:t.gridWidth,readOnly:t.readOnly,showToday:t.showToday,showWeekends:t.showWeekends,showProgress:t.showProgress,colorMap:t.colorMap,theme:t.theme,onTaskClick:d=>{var u,c;return(u=(c=l.current).onTaskClick)===null||u===void 0?void 0:u.call(c,d)},onTaskDblClick:d=>{var u,c;return(u=(c=l.current).onTaskDblClick)===null||u===void 0?void 0:u.call(c,d)},onTaskHover:d=>{var u,c;return(u=(c=l.current).onTaskHover)===null||u===void 0?void 0:u.call(c,d)},onTaskMove:(d,u,c)=>{var h,p;return(h=(p=l.current).onTaskMove)===null||h===void 0?void 0:h.call(p,d,u,c)},onTaskResize:(d,u,c)=>{var h,p;return(h=(p=l.current).onTaskResize)===null||h===void 0?void 0:h.call(p,d,u,c)},onTaskProgressChange:(d,u)=>{var c,h;return(c=(h=l.current).onTaskProgressChange)===null||c===void 0?void 0:c.call(h,d,u)},onDependencyCreate:(d,u,c)=>{var h,p;return(h=(p=l.current).onDependencyCreate)===null||h===void 0?void 0:h.call(p,d,u,c)},onDependencyClick:d=>{var u,c;return(u=(c=l.current).onDependencyClick)===null||u===void 0?void 0:u.call(c,d)},onViewChange:(d,u,c)=>{var h,p;return(h=(p=l.current).onViewChange)===null||h===void 0?void 0:h.call(p,d,u,c)},onTaskSelect:d=>{var u,c;return(u=(c=l.current).onTaskSelect)===null||u===void 0?void 0:u.call(c,d)}}),[t.columns,t.rowHeight,t.barHeight,t.headerHeight,t.gridWidth,t.readOnly,t.showToday,t.showWeekends,t.showProgress,t.colorMap,t.theme]);return(0,Y.useEffect)(()=>{if(!o.current||!pt)return;const d=new pt(o.current,R(R({},g),{},{tasks:t.tasks,dependencies:t.dependencies}));if(i.current=d,t.plugins)for(const u of t.plugins)d.use(u);try{d.setData(t.tasks,t.dependencies)}catch(u){}try{d.expandAll()}catch(u){}return requestAnimationFrame(()=>{try{d.resize()}catch(u){}}),()=>{try{d.destroy()}catch(u){}i.current=null,s.current=!1}},[g]),(0,Y.useEffect)(()=>{if(i.current)try{i.current.setData(t.tasks,t.dependencies),i.current._initialExpanded||(i.current.expandAll(),i.current._initialExpanded=!0)}catch(d){}},[t.tasks,t.dependencies]),(0,Y.useEffect)(()=>{if(i.current&&t.zoomLevel)try{i.current.setZoom(t.zoomLevel)}catch(d){}},[t.zoomLevel]),(0,Y.useEffect)(()=>{const d=o.current;if(!d)return;const u=c=>{const h=i.current;if(!(h!=null&&h.scrollManager))return;c.preventDefault(),c.stopPropagation();const p=h.scrollManager.wrapper;if(p)if(c.shiftKey||Math.abs(c.deltaX)>Math.abs(c.deltaY)){const f=c.shiftKey?c.deltaY:c.deltaX;p.scrollLeft+=f}else p.scrollTop=Math.max(0,p.scrollTop+c.deltaY)};return d.addEventListener("wheel",u,{passive:!1}),()=>d.removeEventListener("wheel",u)},[]),(0,Y.useEffect)(()=>{const d=o.current;if(!d)return;let u=!1,c=!1,h=0,p=0,f=0,v=0;const w=5,D=I=>{var B;const y=i.current;if(!(!(y==null||(B=y.scrollManager)===null||B===void 0)&&B.wrapper)||I.target.tagName!=="CANVAS")return;u=!0,c=!1,h=I.clientX,p=I.clientY;const L=y.scrollManager.wrapper;f=L.scrollLeft,v=L.scrollTop},T=I=>{var B;if(!u)return;const y=I.clientX-h,L=I.clientY-p;if(!c&&(Math.abs(y)>w||Math.abs(L)>w)&&(c=!0,d.style.cursor="grabbing"),!c)return;const A=i.current;if(!(!(A==null||(B=A.scrollManager)===null||B===void 0)&&B.wrapper))return;const C=A.scrollManager.wrapper;C.scrollLeft=f-y,C.scrollTop=Math.max(0,v-L)},H=()=>{u=!1,c&&(c=!1,d.style.cursor="")};return d.addEventListener("mousedown",D),window.addEventListener("mousemove",T),window.addEventListener("mouseup",H),()=>{d.removeEventListener("mousedown",D),window.removeEventListener("mousemove",T),window.removeEventListener("mouseup",H)}},[]),(0,Y.useImperativeHandle)(n,()=>({expandAll:()=>{try{var d;(d=i.current)===null||d===void 0||d.expandAll()}catch(u){}},collapseAll:()=>{try{var d;(d=i.current)===null||d===void 0||d.collapseAll()}catch(u){}},toggleExpand:d=>{try{var u,c;(u=i.current)===null||u===void 0||(c=u.dispatch)===null||c===void 0||c.call(u,{type:"TOGGLE_EXPAND",taskId:d})}catch(h){}},scrollToTask:d=>{try{var u,c;(u=i.current)===null||u===void 0||(c=u.scrollToTask)===null||c===void 0||c.call(u,d)}catch(h){}},scrollToToday:()=>{try{var d,u;(d=i.current)===null||d===void 0||(u=d.scrollToDate)===null||u===void 0||u.call(d,new Date)}catch(c){}},getInstance:()=>i.current,resize:()=>{try{var d;(d=i.current)===null||d===void 0||d.resize()}catch(u){}}}),[]),(0,P.jsx)("div",{ref:o,className:t.className,style:R({position:"absolute",inset:0,width:"100%",height:"100%"},t.style)})}),ce="__bucket_header__";function mt(e){if(!e)return new Date(NaN);const[t,n,o]=e.split("-");return new Date(Date.UTC(Number(t),Number(n)-1,Number(o)))}function bt(e){return`${e.getUTCFullYear()}-${String(e.getUTCMonth()+1).padStart(2,"0")}-${String(e.getUTCDate()).padStart(2,"0")}`}function Yn(e){var t;return(t=e.groupId)!==null&&t!==void 0?t:null}function Un(e){var t;if(e.length===0)return 0;let n=0;for(const o of e)n+=(t=o.progress)!==null&&t!==void 0?t:0;return n/e.length}function Fn(e){var t,n;const o=[...e.buckets].sort((w,D)=>w.order-D.order),i=new Map;o.forEach((w,D)=>i.set(w.id,D));const s=(t=e.getBucket)!==null&&t!==void 0?t:Yn,l=(n=e.getBucketProgress)!==null&&n!==void 0?n:Un,g=new Set;if(e.startCollapsed)for(const w of o)g.add(w.id);const d=new Set;let u=null,c=[],h=null;function p(w,D){c=o.map(T=>({config:T,taskIds:[],allTaskIds:[],collapsed:g.has(T.id),progress:0,startDate:null,endDate:null,totalHours:0}));for(const T of D){const H=w.tasks.get(T);if(!H)continue;const I=s(H);if(!I)continue;const B=i.get(I);B!==void 0&&c[B].taskIds.push(T)}for(const[T,H]of w.tasks){if(T.startsWith(ce))continue;const I=s(H);if(!I)continue;const B=i.get(I);B!==void 0&&c[B].allTaskIds.push(T)}for(const T of c){if(T.allTaskIds.length===0){T.progress=0,T.startDate=null,T.endDate=null,T.totalHours=0;continue}const H=[];let I=1/0,B=-1/0,y=0;for(const L of T.allTaskIds){const A=w.tasks.get(L);if(!A)continue;if(H.push(A),A.startDate){const U=mt(A.startDate).getTime();!isNaN(U)&&U<I&&(I=U)}if(A.endDate){const U=mt(A.endDate).getTime();!isNaN(U)&&U>B&&(B=U)}const C=A.metadata;typeof(C==null?void 0:C.hoursHigh)=="number"&&(y+=C.hoursHigh)}T.startDate=isFinite(I)?new Date(I):null,T.endDate=isFinite(B)?new Date(B):null,T.totalHours=y,T.progress=Math.max(0,Math.min(1,l(H)))}}function f(w){if(!w.startDate||!w.endDate)return null;const D=Math.round(w.progress*100),T=w.totalHours>0?`${w.totalHours}h (${D}%)`:`${w.allTaskIds.length} items`;return{id:`${ce}${w.config.id}`,name:T,startDate:bt(w.startDate),endDate:bt(w.endDate),progress:w.progress,color:w.config.color,status:"group-header",groupBg:w.config.bgTint||void 0,groupColor:w.config.color,groupId:w.config.id,groupName:w.config.label,title:w.config.label,hours:w.totalHours,hoursLabel:`${w.allTaskIds.length} · ${w.totalHours}h`,assignee:"",sortOrder:w.config.order,metadata:{__bucketHeader:!0,bucketId:w.config.id,hoursHigh:w.totalHours,taskCount:w.allTaskIds.length}}}function v(w){if(g.has(w)?g.delete(w):g.add(w),u){const D=u.getState();u.dispatch({type:"SET_SCROLL",x:D.scrollX,y:D.scrollY})}}return{name:"PriorityGroupingPlugin",install(w){u=w,h=w.on("taskClick",((...D)=>{const T=D[0];let H=null;typeof T=="string"?H=T:T&&typeof T=="object"&&"id"in T&&(H=String(T.id)),H&&H.startsWith(ce)&&v(H.substring(17))}))},middleware(w,D){if(w.type==="TOGGLE_EXPAND"&&w.taskId){const y=w.taskId;y.startsWith(ce)||(d.has(y)?d.delete(y):d.add(y))}if(D(w),!u)return;const T=u.getState(),H=[];for(const y of T.tasks.keys())y.startsWith(ce)&&H.push(y);for(const y of H)T.tasks.delete(y);const I=T.flatVisibleIds.filter(y=>!y.startsWith(ce));let B=!1;for(const y of T.tasks.values())if(s(y)!=null){B=!0;break}if(!B){if(c=[],I.length!==T.flatVisibleIds.length){T.flatVisibleIds.length=0;for(const y of I)T.flatVisibleIds.push(y)}return}p(T,I);for(const y of c){if(y.allTaskIds.length===0)continue;const L=f(y);if(L){T.tasks.set(L.id,L);for(const A of y.allTaskIds){const C=T.tasks.get(A);C&&(C.parentId&&T.tasks.has(C.parentId)&&y.allTaskIds.includes(C.parentId)||(C.parentId=L.id))}for(const A of y.allTaskIds)y.allTaskIds.some(C=>{const U=T.tasks.get(C);return U&&U.parentId===A})&&(d.has(A)?T.expandedIds.delete(A):T.expandedIds.add(A));y.collapsed?T.expandedIds.delete(L.id):T.expandedIds.add(L.id)}}u.rebuildTree()},destroy(){h&&h(),u=null,c=[],h=null,g.clear(),d.clear()}}}var Gn=[{id:"top-priority",label:"NOW",color:"#fff",bgTint:"#ef4444",order:0},{id:"active",label:"NEXT",color:"#fff",bgTint:"#f59e0b",order:1},{id:"follow-on",label:"PLANNED",color:"#fff",bgTint:"#10b981",order:2},{id:"proposed",label:"PROPOSED",color:"#fff",bgTint:"#3b82f6",order:3},{id:"deferred",label:"HOLD",color:"#fff",bgTint:"#94a3b8",order:4}];function $e(e){return typeof e=="string"&&e.startsWith(ce)}function Xn(e){let t=0,n=0,o=!1;for(const s of e){const l=s.metadata,g=typeof(l==null?void 0:l.hoursHigh)=="number"?l.hoursHigh:0,d=typeof(l==null?void 0:l.hoursLogged)=="number"?l.hoursLogged:0;g>0&&(t+=g,n+=d,o=!0)}if(!o){var i;if(e.length===0)return 0;let s=0;for(const l of e)s+=(i=l.progress)!==null&&i!==void 0?i:0;return s/e.length}return t>0?Math.min(n/t,1):0}var qn={"top-priority":"#ef4444",active:"#f59e0b","follow-on":"#10b981",proposed:"#3b82f6",deferred:"#94a3b8"},yt={"top-priority":"#f87171",active:"#fbbf24","follow-on":"#34d399",proposed:"#60a5fa",deferred:"#cbd5e1"},Ne={"top-priority":"NOW",active:"NEXT","follow-on":"PLANNED",proposed:"PROPOSED",deferred:"HOLD"},vt={"In Development":"#10b981","QA In Progress":"#10b981","Ready for QA":"#3b82f6","Ready for Development":"#3b82f6","Scoping In Progress":"#f59e0b","Clarification Requested":"#f59e0b",Backlog:"#f59e0b","Deployed to Prod":"#cbd5e1",Done:"#cbd5e1","Ready for UAT Sign-off":"#a78bfa"};function Vn(e,t){const n=e.replace("#",""),o=Math.max(0,Math.round(parseInt(n.substring(0,2),16)*(1-t))),i=Math.max(0,Math.round(parseInt(n.substring(2,4),16)*(1-t))),s=Math.max(0,Math.round(parseInt(n.substring(4,6),16)*(1-t)));return`#${o.toString(16).padStart(2,"0")}${i.toString(16).padStart(2,"0")}${s.toString(16).padStart(2,"0")}`}var Kn={timelineBg:"#ffffff",timelineGridColor:"#e5e7eb",timelineHeaderBg:"#f3f4f6",timelineHeaderText:"#1f2937",timelineWeekendBg:"rgba(229,231,235,0.4)",todayLineColor:"#ef4444",todayBg:"rgba(239,68,68,0.08)",barDefaultColor:"#94a3b8",barBorderRadius:4,barProgressOpacity:.25,barTextColor:"#ffffff",barSelectedBorder:"#3b82f6",gridBg:"#ffffff",gridAltRowBg:"rgba(255,255,255,0)",gridBorderColor:"#e5e7eb",gridTextColor:"#1f2937",gridHeaderBg:"#f3f4f6",gridHeaderText:"#1f2937",gridHoverBg:"rgba(229,231,235,0.3)",dependencyColor:"#3b82f6",dependencyWidth:2,fontFamily:"-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",fontSize:12,selectionColor:"#3b82f6",singleRowHeader:!0};function Qn(e){const t=new Date;t.setHours(0,0,0,0);const n=t.toISOString().slice(0,10),o=new Map(e.map(d=>[d.id,d]));function i(d){if(!d.endDate)return null;if(d.stage==="Done"||d.stage==="Deployed to Prod")return d.endDate;if(d.endDate<n){const u=new Date(t);return u.setDate(u.getDate()+14),u.toISOString().slice(0,10)}return d.endDate}const s=e.filter(d=>d.startDate&&(d.endDate||d.stage!=="Done")),l=new Set;for(const d of s)d.parentWorkItemId&&o.has(d.parentWorkItemId)&&l.add(d.parentWorkItemId);const g=new Map;for(const d of s)if(d.parentWorkItemId&&o.has(d.parentWorkItemId)){const u=d.parentWorkItemId;g.has(u)||g.set(u,{starts:[],ends:[]}),d.startDate&&g.get(u).starts.push(d.startDate);const c=i(d);c&&g.get(u).ends.push(c)}return s.map((d,u)=>{var c,h,p;const f=l.has(d.id),v=d.priorityGroup||"deferred",w=yt[v]||"#94a3b8",D=vt[d.stage]||vt.Backlog,T=f?Vn(w,.2):D,H=d.estimatedHours>0?Math.round(d.loggedHours/d.estimatedHours*100):0,I=d.loggedHours>0?`${d.estimatedHours}h (${H}%)`:`${d.estimatedHours}h`;let B=d.startDate||n,y=i(d)||d.endDate||n;if(f){const C=g.get(d.id);if(C&&C.starts.length>0){const U=[B,...C.starts].sort(),K=[y,...C.ends].sort();B=U[0],y=K[K.length-1]}}const L=d.stage==="Done"||d.stage==="Deployed to Prod"?1:d.estimatedHours>0?Math.min(d.loggedHours/d.estimatedHours,1):0,A=d.parentWorkItemId&&o.has(d.parentWorkItemId)?d.parentWorkItemId:void 0;return{id:d.id,name:f?`${I} · ${((c=(h=g.get(d.id))===null||h===void 0?void 0:h.starts.length)!==null&&c!==void 0?c:0)+1} tasks`:I,title:d.title,startDate:B,endDate:y,progress:L,color:T,assignee:d.developerName||d.entityName||"",parentId:A,groupId:v,groupName:Ne[v]||v,hours:d.estimatedHours,hoursLabel:`${d.estimatedHours}h`,status:d.stage,sortOrder:(p=d.sortOrder)!==null&&p!==void 0?p:u,metadata:{hoursHigh:d.estimatedHours,hoursLogged:d.loggedHours}}})}var Zn=`
  .ng-grid {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
    font-size: 12px !important;
    color: #1f2937 !important;
    letter-spacing: -0.01em;
  }
  .ng-grid table { border-collapse: collapse !important; border-spacing: 0 !important; }
  .ng-grid-header { background: #f3f4f6 !important; visibility: hidden !important; }
  .ng-grid-th { font-size: 12px !important; font-weight: 700 !important; color: #1f2937 !important; padding: 0 6px !important; }
  .ng-grid-row:not(.ng-group-row) .ng-tree-cell .ng-expand-icon + .ng-grid-cell-text { font-weight: 700 !important; color: #1f2937 !important; }
  .ng-grid-row .ng-tree-cell .ng-expand-spacer + .ng-grid-cell-text { font-weight: 400 !important; color: #6b7280 !important; font-size: 11px !important; }
  .ng-grid-cell { padding: 0 6px !important; line-height: 32px !important; border-right: none !important; }
  .ng-expand-spacer { width: 0 !important; min-width: 0 !important; }
  .ng-expand-icon { font-size: 9px !important; opacity: 0.5 !important; color: #6b7280 !important; width: 14px !important; min-width: 14px !important; }
  .ng-expand-icon:hover { opacity: 1 !important; }
  .ng-grid-row { border: none !important; box-shadow: inset 0 -1px 0 #f3f4f6; box-sizing: border-box !important; }
  .ng-grid-row:not(.ng-group-row) { cursor: default; }
  .ng-grid-row:not(.ng-group-row):hover { background: rgba(59,130,246,0.04) !important; outline: 1px solid rgba(59,130,246,0.12) !important; outline-offset: -1px; }
  .ng-row-alt:not(.ng-group-row) { background: unset; }
  .ng-group-row { font-weight: 700; font-size: 11px; letter-spacing: 0.03em; box-sizing: border-box !important; box-shadow: none !important; color: #fff !important; }
  .ng-group-row .ng-grid-cell-text { font-weight: 700 !important; font-size: 12px !important; color: #fff !important; letter-spacing: 0.02em; text-transform: uppercase; }
  .ng-group-row .ng-expand-icon { color: inherit !important; opacity: 0.5 !important; }
  .ng-group-row .ng-grid-cell[data-field="hoursLabel"] { font-weight: 600 !important; font-size: 11px !important; color: inherit !important; opacity: 0.75; white-space: nowrap !important; overflow: visible !important; }
  .ng-grid-cell[data-field="hoursLabel"] { font-family: 'SF Mono', 'Cascadia Code', monospace; font-size: 10px; color: #94a3b8; font-weight: 400; }
  .ng-row-selected:not(.ng-group-row) { background: rgba(59,130,246,0.06) !important; box-shadow: inset 3px 0 0 #3b82f6 !important; }
  .ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 28px"] { padding-left: 8px !important; }
  .ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 48px"] { padding-left: 18px !important; }
  .ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 68px"] { padding-left: 28px !important; }
  .ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 88px"] { padding-left: 38px !important; }
  .ng-scroll-content > canvas { position: sticky !important; left: 0 !important; }
  [data-depth-stripes] { display: none !important; }
  @keyframes mf-depth-check { from { outline-color: transparent; } to { outline-color: transparent; } }
  .ng-gantt-container { animation: mf-depth-check 0.001s linear 1 !important; }
`;function Jn({tasks:e,onTaskClick:t}){const n={},o=["top-priority","active","follow-on","proposed","deferred"];for(const i of o)n[i]=[];for(const i of e){const s=i.priorityGroup||"deferred";n[s]||(n[s]=[]),n[s].push(i)}return(0,P.jsx)("div",{style:{flex:1,overflow:"auto",fontFamily:"-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"},children:o.map(i=>{const s=n[i];if(!s||s.length===0)return null;const l=qn[i]||"#94a3b8",g=s.reduce((c,h)=>c+(h.estimatedHours||0),0),d=s.reduce((c,h)=>c+(h.loggedHours||0),0),u=g>0?Math.round(d/g*100):0;return(0,P.jsxs)("div",{children:[(0,P.jsxs)("div",{style:{background:l,color:"#fff",padding:"6px 12px",fontWeight:700,fontSize:11,letterSpacing:"0.03em",textTransform:"uppercase",display:"flex",justifyContent:"space-between"},children:[(0,P.jsx)("span",{children:Ne[i]||i}),(0,P.jsxs)("span",{style:{opacity:.75,fontWeight:600,fontSize:11},children:[s.length," · ",g,"h (",u,"%)"]})]}),s.map(c=>(0,P.jsxs)("div",{onClick:()=>t(c),style:{padding:"6px 12px 6px "+(c.parentWorkItemId?"28px":"12px"),borderBottom:"1px solid #f3f4f6",display:"flex",alignItems:"center",gap:8,cursor:"pointer",fontSize:12,color:"#1f2937"},onMouseEnter:h=>{h.currentTarget.style.background="rgba(59,130,246,0.04)"},onMouseLeave:h=>{h.currentTarget.style.background=""},children:[(0,P.jsx)("span",{style:{width:8,height:8,borderRadius:"50%",flexShrink:0,background:yt[i]||"#94a3b8"}}),(0,P.jsx)("span",{style:{flex:1,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"},children:c.title}),(0,P.jsxs)("span",{style:{color:"#94a3b8",fontSize:10,flexShrink:0,fontFamily:"monospace"},children:[c.estimatedHours,"h"]}),(0,P.jsx)("span",{style:{fontSize:10,padding:"1px 6px",borderRadius:10,background:"rgba(0,0,0,0.06)",color:"#64748b",flexShrink:0,whiteSpace:"nowrap"},children:c.stage}),c.startDate&&(0,P.jsxs)("span",{style:{color:"#94a3b8",fontSize:10,flexShrink:0},children:[c.startDate," → ",c.endDate||"…"]})]},c.id))]},i)})})}function er({tasks:e}){const t=e.reduce((l,g)=>l+(g.estimatedHours||0),0),n=e.reduce((l,g)=>l+(g.loggedHours||0),0),o=t>0?Math.round(n/t*100):0,i=e.filter(l=>l.startDate&&l.endDate).length,s=e.length-i;return(0,P.jsxs)("div",{style:{background:"#f8fafc",borderBottom:"1px solid #e5e7eb",padding:"4px 12px",display:"flex",gap:16,alignItems:"center",fontSize:11,color:"#64748b",flexShrink:0},children:[(0,P.jsxs)("span",{children:[(0,P.jsx)("b",{style:{color:"#1f2937"},children:e.length})," items"]}),(0,P.jsxs)("span",{children:[(0,P.jsx)("b",{style:{color:"#1f2937"},children:i})," scheduled"]}),s>0&&(0,P.jsxs)("span",{children:[(0,P.jsx)("b",{style:{color:"#f59e0b"},children:s})," unscheduled"]}),(0,P.jsxs)("span",{children:[(0,P.jsxs)("b",{style:{color:"#1f2937"},children:[t,"h"]})," estimated"]}),(0,P.jsxs)("span",{children:[(0,P.jsxs)("b",{style:{color:"#10b981"},children:[n,"h"]})," logged (",o,"%)"]})]})}function tr({tasks:e,onPatch:t,readOnly:n}){const[o,i]=(0,Y.useState)("week"),[s,l]=(0,Y.useState)("gantt"),[g,d]=(0,Y.useState)(null),[u,c]=(0,Y.useState)(!1),h=(0,Y.useRef)(null),p=(0,Y.useRef)(null),f=(0,Y.useMemo)(()=>u?e:e.filter(y=>!y.isInactive),[e,u]),v=(0,Y.useMemo)(()=>Fn({buckets:Gn,getBucket:y=>{var L;return(L=y.groupId)!==null&&L!==void 0?L:null},getBucketProgress:Xn}),[]),w=(0,Y.useMemo)(()=>Qn(f),[f]),D=(0,Y.useMemo)(()=>[{field:"title",header:"",width:220,tree:!0},{field:"hoursLabel",header:"",width:70,align:"right"}],[]);(0,Y.useEffect)(()=>{if(s!=="gantt")return;const y=setTimeout(()=>{var L,A;const C=(L=h.current)===null||L===void 0||(A=L.getInstance)===null||A===void 0?void 0:A.call(L);if(C!=null&&C.timeScale&&(C!=null&&C.scrollManager)){const U=new Date;U.setDate(U.getDate()-14);const K=C.timeScale.dateToX(U);C.scrollManager.scrollToX(Math.max(0,K))}},600);return()=>clearTimeout(y)},[s,w]),(0,Y.useEffect)(()=>{if(s!=="gantt")return;const y=p.current;if(!y)return;const L=new Map(f.map(q=>[q.id,q])),A=new Map;function C(q){if(A.has(q))return A.get(q);const G=L.get(q);if(!G||!G.parentWorkItemId||!L.has(G.parentWorkItemId))return A.set(q,0),0;const Z=1+C(G.parentWorkItemId);return A.set(q,Z),Z}for(const q of f)C(q.id);const U=q=>{const G=q.match(/(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/);return G?{r:+G[1],g:+G[2],b:+G[3]}:null};let K=!1;const J=y.querySelector(".ng-scroll-content"),F=()=>{if(K)return;K=!0;const q=y.querySelectorAll(".ng-grid-row");let G=null;const Z=[];for(const a of q){var ne;const b=a;if(b.classList.contains("ng-group-row")){const _=U(b.style.background||"");_&&Z.push({top:b.offsetTop,height:b.offsetHeight,color:`rgba(${_.r},${_.g},${_.b},0.18)`}),G=_;continue}const k=b.getAttribute("data-task-id")||"",E=(ne=A.get(k))!==null&&ne!==void 0?ne:0;if(G){const _=Math.max(.03,.12-E*.04),$=`rgba(${G.r},${G.g},${G.b},${_})`;Z.push({top:b.offsetTop,height:b.offsetHeight,color:$}),b.style.setProperty("background",$,"important")}else b.style.removeProperty("background")}if(J&&Z.length>0){const a=J.querySelector("canvas");if(a){const _=a.offsetWidth||a.width;_>0&&(J.style.backgroundSize=_+"px 100%",J.style.backgroundRepeat="no-repeat")}const b=J.scrollHeight||2e3,k=[];let E=0;for(const _ of Z)_.top>E&&k.push(`transparent ${E}px`,`transparent ${_.top}px`),k.push(`${_.color} ${_.top}px`,`${_.color} ${_.top+_.height}px`),E=_.top+_.height;E<b&&k.push(`transparent ${E}px`,`transparent ${b}px`),J.style.backgroundImage=`linear-gradient(to bottom, ${k.join(", ")})`}const se=y.querySelectorAll(".ng-grid-row:not(.ng-group-row)");for(const a of se){var re;const b=a,k=!!b.querySelector(".ng-expand-icon"),E=b.getAttribute("data-task-id")||"",_=(re=A.get(E))!==null&&re!==void 0?re:0,$=b.querySelector(".ng-tree-cell");if(!$)continue;const M=k?`${_*12}px`:`${_*10}px`;$.style.getPropertyValue("padding-left")!==M&&$.style.setProperty("padding-left",M,"important")}K=!1},ie=requestAnimationFrame(F);let ee=null;const te=new MutationObserver(()=>{K||(ee&&clearTimeout(ee),ee=setTimeout(F,50))});return te.observe(y,{childList:!0,subtree:!0}),()=>{cancelAnimationFrame(ie),ee&&clearTimeout(ee),te.disconnect(),J&&(J.style.backgroundImage="",J.style.backgroundSize="",J.style.backgroundRepeat="")}},[s,f]);const T=(0,Y.useCallback)(y=>{!(y!=null&&y.id)||$e(y.id)||d(f.find(L=>L.id===y.id)||null)},[f]),H=(0,Y.useCallback)((y,L,A)=>{!(y!=null&&y.id)||$e(y.id)||n||t({id:y.id,startDate:L,endDate:A})},[t,n]),I=(0,Y.useCallback)((y,L,A)=>{!(y!=null&&y.id)||$e(y.id)||n||t({id:y.id,startDate:L,endDate:A})},[t,n]),B=(0,Y.useCallback)(y=>{d(y)},[]);return(0,P.jsxs)("div",{style:{height:"100%",display:"flex",flexDirection:"column",fontFamily:"-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",overflow:"hidden",background:"#f8fafc"},children:[(0,P.jsx)("style",{children:Zn}),(0,P.jsxs)("div",{style:{background:"#fff",borderBottom:"1px solid #e5e7eb",padding:"6px 12px",display:"flex",alignItems:"center",gap:8,flexShrink:0,flexWrap:"wrap"},children:[(0,P.jsx)("span",{style:{fontWeight:700,fontSize:13,color:"#0f172a"},children:"Delivery Timeline"}),(0,P.jsx)("span",{style:{color:"#e2e8f0"},children:"|"}),["gantt","list"].map(y=>(0,P.jsx)("button",{onClick:()=>l(y),style:{fontSize:10,fontWeight:600,padding:"3px 8px",borderRadius:999,border:"1px solid",cursor:"pointer",background:s===y?"#7c3aed":"#fff",color:s===y?"#fff":"#64748b",borderColor:s===y?"#7c3aed":"#e2e8f0"},children:y==="gantt"?"▤ Gantt":"☰ List"},y)),(0,P.jsx)("span",{style:{color:"#e2e8f0"},children:"|"}),["day","week","month","quarter"].map(y=>(0,P.jsx)("button",{onClick:()=>i(y),style:{fontSize:10,fontWeight:600,padding:"3px 8px",borderRadius:999,border:"1px solid",cursor:"pointer",background:o===y?"#1e293b":"#fff",color:o===y?"#fff":"#64748b",borderColor:o===y?"#1e293b":"#e2e8f0",display:s==="gantt"?void 0:"none"},children:y.charAt(0).toUpperCase()+y.slice(1)},y)),(0,P.jsx)("div",{style:{flex:1}}),e.some(y=>y.isInactive)&&(0,P.jsx)("button",{onClick:()=>c(y=>!y),style:{fontSize:10,fontWeight:600,padding:"3px 8px",borderRadius:999,border:"1px solid",cursor:"pointer",background:u?"#0f172a":"#fff",color:u?"#fff":"#64748b",borderColor:u?"#0f172a":"#e2e8f0"},title:u?"Hide inactive items":"Show inactive items",children:u?"Hide inactive":"Show inactive"}),n&&(0,P.jsx)("span",{style:{fontSize:10,color:"#94a3b8",fontStyle:"italic"},children:"Read-only"})]}),(0,P.jsx)(er,{tasks:f}),(0,P.jsx)("div",{style:{flex:1,overflow:"hidden",display:"flex",flexDirection:"column"},children:s==="gantt"?(0,P.jsx)("div",{ref:p,style:{flex:1,overflow:"hidden"},children:(0,P.jsx)(Wn,{ref:h,tasks:w,columns:D,zoomLevel:o,rowHeight:32,barHeight:18,gridWidth:300,readOnly:n,showToday:!0,showWeekends:!0,showProgress:!0,plugins:[v],theme:Kn,onTaskClick:T,onTaskMove:H,onTaskResize:I,style:{height:"100%"}})}):(0,P.jsx)(Jn,{tasks:f,onTaskClick:B})}),g&&(0,P.jsxs)("div",{style:{position:"absolute",right:0,top:0,bottom:0,width:300,background:"#fff",borderLeft:"1px solid #e5e7eb",boxShadow:"-4px 0 16px rgba(0,0,0,0.08)",display:"flex",flexDirection:"column",zIndex:50,fontFamily:"-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"},children:[(0,P.jsxs)("div",{style:{padding:"10px 12px",borderBottom:"1px solid #e5e7eb",display:"flex",justifyContent:"space-between",alignItems:"flex-start"},children:[(0,P.jsxs)("div",{children:[(0,P.jsx)("div",{style:{fontWeight:700,fontSize:13,color:"#0f172a",marginBottom:2},children:g.title}),(0,P.jsx)("div",{style:{fontSize:10,color:"#64748b"},children:g.developerName||g.entityName})]}),(0,P.jsx)("button",{onClick:()=>d(null),style:{background:"none",border:"none",cursor:"pointer",fontSize:16,color:"#94a3b8",padding:0,lineHeight:1},children:"×"})]}),(0,P.jsx)("div",{style:{flex:1,overflow:"auto",padding:12},children:[["Stage",g.stage],["Priority",g.priority],["Group",Ne[g.priorityGroup]||g.priorityGroup],["Start",g.startDate||"—"],["End",g.endDate||"—"],["Estimated",`${g.estimatedHours}h`],["Logged",`${g.loggedHours}h`],["Progress",g.estimatedHours>0?`${Math.round(g.loggedHours/g.estimatedHours*100)}%`:"—"]].map(([y,L])=>(0,P.jsxs)("div",{style:{display:"flex",justifyContent:"space-between",padding:"4px 0",borderBottom:"1px solid #f1f5f9",fontSize:12},children:[(0,P.jsx)("span",{style:{color:"#94a3b8",fontWeight:500},children:y}),(0,P.jsx)("span",{style:{color:"#1e293b",fontWeight:600},children:L})]},y))})]})]})}try{window.DeliveryTimeline={mount(e,t){var n,o;const i=R(R({},t),{},{onPatch:(n=(o=t.onPatch)!==null&&o!==void 0?o:t.onSave)!==null&&n!==void 0?n:(()=>{})});Ue.default.render(Y.createElement(tr,i),e)},unmount(e){Ue.default.unmountComponentAtNode(e)}},console.log("[DeliveryTimeline] Bundle initialized successfully. React version:","19.2.3")}catch(e){console.error("[DeliveryTimeline] Bundle initialization failed:",e),window.DeliveryTimeline={mount(t){t.innerHTML=`<div style="padding:20px;color:#b91c1c;font-family:sans-serif">
        <strong>DeliveryTimeline failed to initialize.</strong><br/>
        Check browser console for details.
      </div>`},unmount(){}}}})();
