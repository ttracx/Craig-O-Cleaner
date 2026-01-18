package com.craigoclean.android.di

import android.content.Context
import com.android.billingclient.api.BillingClient
import com.craigoclean.android.billing.BillingRepository
import com.craigoclean.android.billing.EntitlementManager
import com.craigoclean.android.data.local.PreferencesDataStore
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import javax.inject.Singleton

/**
 * Module providing billing-related dependencies
 */
@Module
@InstallIn(SingletonComponent::class)
object BillingModule {

    @Provides
    @Singleton
    fun provideBillingClient(
        @ApplicationContext context: Context
    ): BillingClient {
        return BillingClient.newBuilder(context)
            .enablePendingPurchases()
            .build()
    }

    @Provides
    @Singleton
    fun provideBillingRepository(
        @ApplicationContext context: Context,
        billingClient: BillingClient,
        preferencesDataStore: PreferencesDataStore,
        @ApplicationScope applicationScope: CoroutineScope
    ): BillingRepository {
        return BillingRepository(
            context = context,
            billingClient = billingClient,
            preferencesDataStore = preferencesDataStore,
            externalScope = applicationScope
        )
    }

    @Provides
    @Singleton
    fun provideEntitlementManager(
        billingRepository: BillingRepository,
        preferencesDataStore: PreferencesDataStore,
        @ApplicationScope applicationScope: CoroutineScope
    ): EntitlementManager {
        return EntitlementManager(
            billingRepository = billingRepository,
            preferencesDataStore = preferencesDataStore,
            externalScope = applicationScope
        )
    }
}
